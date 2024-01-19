#/bin/bash

## If you run the script a second time over a directory. 
## Zipped files that had the somename.extension.zip format will 
## be renamed to somename_extension.zip

# Get the current date and time
current_datetime=$(date +"%Y-%m-%d_%H-%M-%S")

# Define the script name
script_name="replace_dots_spaces_single_quotes_shrink_JPG_and_ZIP_files"

# Define the output and error file paths with date and time
output_file="${script_name}_${current_datetime}_output.log"
error_file="${script_name}_${current_datetime}_error.log"

# Redirect standard output to the output file
exec > >(tee "$output_file") 2> >(tee "$error_file" >&2)

# Function to store original owner and permissions of directories
store_original_permissions_filedir() {
    local filedir="$1"
    original_owner=$(stat -c "%u:%g" "$filedir")  
    original_permissions=$(stat -c "%a" "$filedir")
}

# Function to restore original owner and permissions of directories
restore_original_permissions_filedir() {
    local filedir="$1"

    # Restore original owner and permissions
    chown "$original_owner" "$filedir"
    chmod "$original_permissions" "$filedir"
    echo "Restored owner, group and permissions for: $filedir"
}

# Function to rename directories
rename_directories() {
    local current_dir="$1"

    for dir in "$current_dir"/*/; do
        if [ -d "$dir" ]; then
        
        	# Store original owner and permissions before renaming
        	store_original_permissions_filedir "$dir"
        	
		    parent_dir=$(dirname "$dir")
		    base_dir=$(basename "$dir")
		    new_dir=$(echo "$base_dir" | sed -e "s/[^a-zA-Z0-9._]/_/g" -e "s/[. ]/_/g" | sed "s/__/_/g" )
		    if [ "$base_dir" != "$new_dir" ]; then
		     #Check for double underscores and replace by single
		    	mv "$dir" "$parent_dir/$new_dir"
		   	echo "Renamed: $base_dir -> $new_dir"
		           
		           # Restore original owner and permissions after renaming
			   restore_original_permissions_filedir "$parent_dir/$new_dir"
		    fi
        fi
    done
}

# Function to recursively process directories
process_directories_recursive() {
    local start_dir="$1"

    rename_directories "$start_dir"

    for dir in "$start_dir"/*/; do
        if [ -d "$dir" ]; then
            process_directories_recursive "$dir"
        fi
    done
}

# Function to rename files at the current level
rename_files() {
    local current_dir="$1"

    for file in "$current_dir"/*; do
        if [ -f "$file" ]; then
        
          # Store original owner and permissions before renaming
            store_original_permissions_filedir "$file"
            
		    base_file=$(basename "$file")
		    extension="${base_file##*.}"
		    filename="${base_file%.*}"
		    new_filename=$(echo "$filename" | sed -e "s/[^a-zA-Z0-9._]/_/g" -e "s/[. ]/_/g" | sed "s/__/_/g" )
		    new_file="$current_dir/$new_filename.$extension"
		    if [ "$base_file" != "$new_filename.$extension" ]; then
			   mv "$file" "$new_file"
			   
			     # Restore original owner and permissions after renaming
				restore_original_permissions_filedir "$new_file"
				echo "Renamed file: $base_file -> $new_filename.$extension"
                
            fi
        fi
    done
}

# Function to recursively rename files in all directories
rename_files_recursive() {
    local start_dir="$1"

    rename_files "$start_dir"

    for dir in "$start_dir"/*/; do
        if [ -d "$dir" ]; then
            rename_files_recursive "$dir"
        fi
    done
}

# Run jpegoptim on all JPEG files (jpg and jpeg) in the current directory
run_jpegoptim() {
	start_dir=$1
        find "$start_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -exec jpegoptim --max=60 -f --strip-all {} \;
}
 
# Check for the command-line argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <start_directory>"
    exit 1
fi

# Define file extensions to exclude
exclude_extensions=("avi" "mp4" "mov" "mkv" "flv" "wmv" "jpg" "jpeg" "png" "gif" "bmp" "zip" "gz" "tar" "bz2" "rar" "7z" "mp3" "ogg" "wav" "flac" "aac")

# Function to check if a file should be excluded
should_exclude() {
    local file="$1"
    local ext="${file##*.}"
    for excluded_ext in "${exclude_extensions[@]}"; do
        if [[ "$ext" == "$excluded_ext" || "$ext" == "${excluded_ext^^}" ]]; then
            return 0 # Should exclude
        fi
    done
            return 1 # Should not exclude    
}

# Find and compress files recursively, overwriting original files
compress_files() {
	start_dir=$1
	find "$start_dir" -type f -print | while IFS= read -r file; do
	    if should_exclude "$file"; then
		echo "Excluding: $file"
	    else
	    	# Store original owner and permissions before renaming
                store_original_permissions_filedir "$file"
			zip -j "$file.zip" "$file" && rm "$file"
		# Restore original owner and permissions after renaming
		restore_original_permissions_filedir "$file.zip"	
	    fi
	done
}

# Execute the functions
rename_directories $1
process_directories_recursive $1
rename_files_recursive "$1"
run_jpegoptim $1
compress_files $1

echo "Done! Original files replaced with compressed versions."
echo "Done! Optimized jpg files."
echo "Done! Removed "." ":spaces" in folders and files."
echo "Done! Restored original ID's and permissions."
echo "Output and error log files created."

# Reset redirection to the default (terminal)
exec >&-

# Optionally, you can also reset standard error redirection
exec 2>&-

