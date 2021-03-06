#! /bin/bash
#
# Update the version file each day for the daily build
#

# Exit on error
set -e

# Parsing logic

usage()
{
    echo "$0 <options>"
    echo
    echo "Valid options are:"
    echo "  -f:  Version file to update (mandatory option)"
    echo "  -h:  This message"
    echo "  -i:  Increment build number and set date"
    echo "  -r:  Set for release build"
    echo "  -v:  Verbose output"
    echo
    echo "With only the -f option specified, -i is assumed"

    exit 1
}

P_INCREMENT=0
P_RELEASE=0
VERBOSE=0

while getopts "h?f:irv" opt; do
    case "$opt" in
        h|\?)
            usage
            ;;
	f)
	    VERSION_FILE=$OPTARG
	    ;;

        i)
            P_INCREMENT=1
            ;;
        r)
            P_RELEASE=1
            ;;
        v)
            VERBOSE=1
            ;;
    esac
done
shift $((OPTIND-1))

if [ "$@ " != " " ]; then
    echo "Parsing error: '$@' is unparsed, use -h for help" 1>& 2
    exit 1
fi

if [ -z "$VERSION_FILE" ]; then
    echo "Must specify -f qualifier (version file)" 1>& 2
    exit 1
fi

if [ ! -f $VERSION_FILE ]; then
    echo "Can't find file $VERSION_FILE" 1>& 2
    exit 1
fi

if [ ! -w $VERSION_FILE ]; then
    echo "File $VERSION_FILE is not writeable" 1>& 2
    exit 1
fi

# Set default behavior
[ $P_RELEASE -eq 0 ] && P_INCREMENT=1

# Increment build number
if [ $P_INCREMENT -ne 0 ]; then
    VERSION_OLD=`grep '^[A-Z]*_BUILDVERSION_BUILDNR' $VERSION_FILE | cut -d= -f2`
    DATE_OLD=`grep '^[A-Z]*_BUILDVERSION_DATE' $VERSION_FILE | cut -d= -f2`

    VERSION_NEW=$(( $VERSION_OLD + 1 ))
    DATE_NEW=`date +%Y%m%d`

    perl -i -pe "s/(^[A-Z]*_BUILDVERSION_BUILDNR)=.*/\1=$VERSION_NEW/" $VERSION_FILE
    perl -i -pe "s/(^[A-Z]*_BUILDVERSION_DATE)=.*/\1=$DATE_NEW/" $VERSION_FILE

    if [ $VERBOSE -ne 0 ]; then
        echo "Updated version number, Was: $VERSION_OLD, Now $VERSION_NEW"
        echo "Updated release date,   Was: $DATE_OLD, Now $DATE_NEW"
    fi

    # Since build number is incremented, update the nuget version as well
    # Nuget version is formatting: major.minor.1<2-digit-patch><3-digit-build>
    #
    # For this, it's easier just to load the version file ...

    . $VERSION_FILE

    if [ -z "$OMI_BUILDVERSION_MAJOR" \
         -o -z "$OMI_BUILDVERSION_MINOR" \
         -o -z "$OMI_BUILDVERSION_PATCH" \
         -o -z "$OMI_BUILDVERSION_BUILDNR" ]; then
        echo "Unale to recognize OMI versioning after sourcing version file" 1>& 2
        exit 1
    fi

    # Sanity test that the patch number is short enough for nuget encoding
    if [ ${#OMI_BUILDVERSION_PATCH} -gt 2 ]; then
        echo "\$OMI_BUILDVERSION_PATCH is too long for nuget encoding"
        exit 1
    fi

    # Verify that the new build number isn't too long for nuget encoding
    if [ ${#VERSION_NEW} -gt 3 ]; then
        echo "New build version number is too long for nuget encoding"
        exit 1
    fi

    NUGET_VERSION=`printf "%d.%d.1%02d%03d" $OMI_BUILDVERSION_MAJOR $OMI_BUILDVERSION_MINOR $OMI_BUILDVERSION_PATCH $OMI_BUILDVERSION_BUILDNR`

    perl -i -pe "s/(^[A-Z]*_BUILDVERSION_NUGET)=.*/\1=$NUGET_VERSION/" $VERSION_FILE

    if [ $VERBOSE -ne 0 ]; then
        echo "Updated nuget version,  Was: $OMI_BUILDVERSION_NUGET, Now $NUGET_VERSION"
    fi

fi

# Set release build
if [ $P_RELEASE -ne 0 ]; then
    perl -i -pe "s/^([A-Z]*_BUILDVERSION_STATUS)=.*/\1=Release_Build/" $VERSION_FILE
    [ $VERBOSE -ne 0 ] && echo "Set BUILDVERSION_STATUS to \"Release_Build\""
    echo "WARNING: Never commit $VERSION_FILE with release build set!" 1>& 2
fi

exit 0
