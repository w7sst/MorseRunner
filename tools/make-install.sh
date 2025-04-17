#!/bin/bash

# Verification method (cksum or diff)
VERIFY_METHOD="diff"

# List of files to copy (modify this list as needed)
FILES=(
  "MorseRunner.exe"
  "Readme.txt"
  "HstResults.txt"
  "ARRLDXCW_USDX.txt"
  "CQWWCW.txt"
  "CWOPS.LIST"
  "DXCC.LIST"
  "FDGOTA.txt"
  "IARU_HF.txt"
  "JARL_ACAG.TXT"
  "JARL_ALLJA.TXT"
  "K1USNSST.txt"
  "MASTER.DTA"
  "NAQPCW.txt"
  "SSCW.txt"
)

# Function to display the usage of the script
usage() {
  echo "Usage: $0 [options] destination_directory"
  echo "With options:"
  echo "  -u, --update    Update the list of files within an existing direcotry."
  echo "  -v, --verify    Verify the list of files exist without copying."
  echo "  -h, --help      Help message."
  echo "If no option is provided and the destimation directory does not exist,"
  echo "the destination directory is created and the files are copied;"
  echo "otherwise an error is reported without changing any files."
  echo ""
  echo "Example: $0 '../Morse Runner 1.85.2'"
}

# Function to verify the integrity of the installed files using cksum or diff
verify_files() {
  for i in "${!FILES[@]}"; do
    ORIGINAL_FILE="${FILES[$i]}"
    INSTALLED_FILE="$INSTALL_DIR/$(basename "$ORIGINAL_FILE")"
    
    if [ -f "$INSTALLED_FILE" ]; then
      echo "Verifying $INSTALLED_FILE..."
      
      if [ "$VERIFY_METHOD" == "cksum" ]; then
        # Compare using cksum
        original_cksum=$(cksum "$ORIGINAL_FILE" | awk '{print $1}')
        installed_cksum=$(cksum "$INSTALLED_FILE" | awk '{print $1}')
        
        #if [ "$original_cksum" == "$installed_cksum" ]; then
        #  echo "$INSTALLED_FILE: Integrity verified using cksum."
        #else
        #  echo "$INSTALLED_FILE: Integrity check failed (cksum mismatch)."
        #fi
        if [ "$original_cksum" != "$installed_cksum" ]; then
          echo "$INSTALLED_FILE: Integrity check failed (cksum mismatch)."
        fi
      elif [ "$VERIFY_METHOD" == "diff" ]; then
        # Compare using diff
        diff "$ORIGINAL_FILE" "$INSTALLED_FILE" > /dev/null
        #if [ $? -eq 0 ]; then
        #  echo "$INSTALLED_FILE: Integrity verified using diff."
        #else
        #  echo "$INSTALLED_FILE: Integrity check failed (diff mismatch)."
        #fi
        if [ $? -ne 0 ]; then
          echo "$INSTALLED_FILE: Integrity check failed (diff mismatch)."
        fi
      else
        echo "Invalid verification method. Use 'cksum' or 'diff'."
        exit 1
      fi
    else
      echo "Warning: $INSTALLED_FILE does not exist for verification."
    fi
  done
}

# Flag to check if we need to verify instead of copy
VERIFY=false
UPDATE=false

OPTS=$(getopt -o vuh -l verify,update,help --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
  usage
  exit 1;
fi

eval set -- "$OPTS"
while true; do
  case "$1" in
    -v|--verify)  VERIFY=true; shift ;;
    -u|--update)  UPDATE=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    --)           shift; break;;
    *)            echo "Invalid Option: $1"; usage; exit 1 ;;
  esac
done

shift $((OPTIND - 1))

# Check if there are at least 1 argument (destination directory)
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

# Check for incompatible options
if $UPDATE && $VERIFY; then
  echo "Error: --update cannot be used with --verify option."
  usage
  exit 1
fi

# Extract the installation directory (last argument)
INSTALL_DIR="$1"

# Verify the integrity of the copied files if the verification method is provided
if $VERIFY; then
  if [ ! -d "$INSTALL_DIR" ]; then
    echo "Error: Directory '$INSTALL_DIR' does not exist. Unable to verify files."
    exit 1
  fi
  verify_files
  exit
fi

# Ensure the installation directory exists
if [ ! -d "$INSTALL_DIR" ]; then
  echo "Directory '$INSTALL_DIR' does not exist. Creating it now."
  mkdir -p "$INSTALL_DIR"
elif ! $UPDATE; then
  echo "Error: Directory '$INSTALL_DIR' exists."
  echo "Please use the [-u | --update] option to update an existing directory."
  exit 1
fi

# Loop through the list of files and copy them
echo "Removing existing files in $INSTALL_DIR/*"
rm -rf "$INSTALL_DIR/*"
for FILE in "${FILES[@]}"; do
  if [ -e "$FILE" ]; then
    echo "Copying $FILE to $INSTALL_DIR"
    cp -p "$FILE" "$INSTALL_DIR/"
  else
    echo "Warning: $FILE does not exist, skipping."
  fi
done

echo "Files have been copied to $INSTALL_DIR."

