#!/bin/bash
#
# =========================================================================
# Title:         Image Optimizer Terminal for WordPress
# Description:   Optimizes JPG, PNG, GIF and WebP images recursively
# Author:        David Carrero Fernández-Baillo <dcarrero@stackscale.com>
# Website:       https://carrero.es
# GitHub:        https://github.com/dcarrero
# Twitter/X:     @carrero
# Version:       0.1 beta
# Created:       2025-04-12
# License:       MIT License
# =========================================================================

# Default configuration
IMAGES_DIR="."
LOG_FILE="./image_optimization.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
RECURSIVE=true              # Process subdirectories recursively
ENABLE_LOG=true             # Enable logging
JPG_QUALITY=85              # JPG quality (0-100)
PNG_LEVEL=3                 # PNG optimization level (0-7)
WEBP_QUALITY=80             # WebP quality (0-100)
DRY_RUN=false               # Simulation mode
SKIP_JPG=false              # Skip JPG optimization
SKIP_PNG=false              # Skip PNG optimization
SKIP_GIF=false              # Skip GIF optimization
SKIP_WEBP=false             # Skip WebP optimization
QUIET=false                 # Quiet mode
VERBOSE=false               # Verbose mode
TOTAL_ORIGINAL=0            # Tracking statistics
TOTAL_OPTIMIZED=0
TOTAL_SAVED=0
TOTAL_FILES=0

# Check if webp is available in the system
WEBP_AVAILABLE=false
if command -v cwebp &> /dev/null; then
	WEBP_AVAILABLE=true
fi

# Show help
show_help() {
	cat << EOF
Usage: $(basename "$0") [OPTIONS]

Script to optimize images (JPG, JPEG, PNG, GIF, WebP) for WordPress and other websites.

Options:
  -h, --help                 Show this help
  -d, --dir DIR              Images directory (default: current directory)
  -l, --log FILE             Log file (default: ./image_optimization.log)
  --no-recursive             Don't process subdirectories
  --no-log                   Don't generate log file
  --jpg-quality N            JPG/JPEG quality (0-100) (default: 85)
  --png-level N              PNG optimization level (0-7) (default: 3)
  --webp-quality N           WebP quality (0-100) (default: 80)
  --dry-run                  Run without changing files (simulation)
  --skip-jpg                 Skip JPG/JPEG optimization
  --skip-png                 Skip PNG optimization
  --skip-gif                 Skip GIF optimization
  --skip-webp                Skip WebP optimization
  --quiet                    Quiet mode (errors only)
  --verbose                  Verbose mode

Examples:
  $(basename "$0") -d /var/www/html/wp-content/uploads
  $(basename "$0") --dir ./photos --jpg-quality 90 --no-recursive
  $(basename "$0") --dry-run -d /var/www/uploads -l /tmp/optimization.log

EOF
	exit 0
}

# Parse arguments
parse_arguments() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				show_help
				;;
			-d|--dir)
				IMAGES_DIR="$2"
				shift 2
				;;
			-l|--log)
				LOG_FILE="$2"
				shift 2
				;;
			-r|--recursive)
				RECURSIVE=true
				shift
				;;
			--no-recursive)
				RECURSIVE=false
				shift
				;;
			--no-log)
				ENABLE_LOG=false
				shift
				;;
			--jpg-quality)
				JPG_QUALITY="$2"
				shift 2
				;;
			--png-level)
				PNG_LEVEL="$2"
				shift 2
				;;
			--webp-quality)
				WEBP_QUALITY="$2"
				shift 2
				;;
			--dry-run)
				DRY_RUN=true
				shift
				;;
			--skip-jpg)
				SKIP_JPG=true
				shift
				;;
			--skip-png)
				SKIP_PNG=true
				shift
				;;
			--skip-gif)
				SKIP_GIF=true
				shift
				;;
			--skip-webp)
				SKIP_WEBP=true
				shift
				;;
			--quiet)
				QUIET=true
				shift
				;;
			--verbose)
				VERBOSE=true
				shift
				;;
			*)
				echo "Unknown option: $1"
				echo "Use --help to see available options"
				exit 1
				;;
		esac
	done
}

# Log message with appropriate levels
log_message() {
	local message="$1"
	local level="$2"  # 0=error, 1=info, 2=verbose
	
	# Don't show info messages in quiet mode
	if [ "$QUIET" = true ] && [ "$level" -eq 1 ]; then
		return
	fi
	
	# Only show verbose messages in verbose mode
	if [ "$level" -eq 2 ] && [ "$VERBOSE" = false ]; then
		return
	fi
	
	# Prefix based on level
	local prefix=""
	if [ "$level" -eq 0 ]; then
		prefix="[ERROR] "
	elif [ "$level" -eq 2 ]; then
		prefix="[DEBUG] "
	fi
	
	if [ "$ENABLE_LOG" = true ]; then
		echo "${prefix}${message}" | tee -a "$LOG_FILE"
	else
		echo "${prefix}${message}"
	fi
}

# Check for required dependencies
check_dependencies() {
	local missing_deps=()
	local required_tools=()
	
	# Always required tools
	required_tools=(find bc) # bc for calculations
	
	# Add tools based on enabled formats
	if [ "$SKIP_JPG" = false ]; then 
		required_tools+=(jpegoptim)
	fi
	
	if [ "$SKIP_PNG" = false ]; then 
		required_tools+=(optipng)
	fi
	
	if [ "$SKIP_GIF" = false ]; then 
		required_tools+=(gifsicle)
	fi
	
	if [ "$SKIP_WEBP" = false ] && [ "$WEBP_AVAILABLE" = true ]; then 
		required_tools+=(cwebp)
	fi
	
	# Handle stat command differently between macOS and Linux
	if [[ "$OSTYPE" == "darwin"* ]]; then
		if ! command -v gstat &> /dev/null; then
			missing_deps+=("gstat (GNU stat from coreutils)")
		fi
	else
		required_tools+=(stat)
	fi
	
	for cmd in "${required_tools[@]}"; do
		if ! command -v "$cmd" &> /dev/null; then
			missing_deps+=("$cmd")
		fi
	done
	
	if [ ${#missing_deps[@]} -ne 0 ]; then
		log_message "Missing dependencies: ${missing_deps[*]}" 0
		
		if [[ "$OSTYPE" == "darwin"* ]]; then
			log_message "Install dependencies on macOS with:" 1
			log_message "brew install jpegoptim optipng gifsicle webp coreutils bc" 1
		elif [ -f /etc/debian_version ]; then
			log_message "Install dependencies on Debian/Ubuntu with:" 1
			log_message "sudo apt-get install jpegoptim optipng gifsicle webp bc" 1
		elif [ -f /etc/redhat-release ]; then
			log_message "Install dependencies on CentOS/RHEL/CloudLinux with:" 1
			log_message "sudo yum install epel-release" 1
			log_message "sudo yum install jpegoptim optipng gifsicle bc" 1
			if [ "$SKIP_WEBP" = false ] && [ "$WEBP_AVAILABLE" = false ]; then
				log_message "Note: WebP tools are not available in standard repositories for your system." 1
				log_message "WebP processing will be skipped. If you need WebP support, compile from source or" 1
				log_message "find an alternative repository with WebP tools." 1
				SKIP_WEBP=true
			fi
		else
			log_message "Install the missing dependencies using your package manager" 1
			if [ "$SKIP_WEBP" = false ] && [ "$WEBP_AVAILABLE" = false ]; then
				log_message "Note: WebP support will be skipped" 1
				SKIP_WEBP=true
			fi
		fi
		exit 1
	fi
}

# Check if directory exists and is writable
check_directory() {
	if [ ! -d "$IMAGES_DIR" ]; then
		log_message "Directory does not exist: $IMAGES_DIR" 0
		exit 1
	fi
	
	if [ ! -w "$IMAGES_DIR" ] && [ "$DRY_RUN" = false ]; then
		log_message "No write permission on $IMAGES_DIR" 0
		log_message "Use --dry-run to test without writing or run with proper permissions" 1
		exit 1
	fi
}

# Get file size based on OS
get_file_size() {
	local file="$1"
	if [[ "$OSTYPE" == "darwin"* ]]; then
		# macOS requires gstat (GNU stat from coreutils)
		gstat -c %s "$file"
	else
		# Linux
		stat -c %s "$file"
	fi
}

# Optimize a single image
optimize_image() {
	local img="$1"
	local img_type="$2"
	local before_size=$(get_file_size "$img")
	local output=""
	local status="unchanged"
	
	# Show that we're starting to process this file
	echo -n "Processing: $img ($img_type, $before_size bytes)... "
	
	# Don't make actual changes in dry-run mode
	if [ "$DRY_RUN" = false ]; then
		case "$img_type" in
			jpg|jpeg)
				if [ "$SKIP_JPG" = false ]; then
					jpegoptim --strip-all --max="$JPG_QUALITY" --quiet "$img"
				fi
				;;
			png)
				if [ "$SKIP_PNG" = false ]; then
					optipng -o"$PNG_LEVEL" -quiet "$img"
				fi
				;;
			gif)
				if [ "$SKIP_GIF" = false ]; then
					gifsicle -b -O3 "$img" 2>/dev/null
				fi
				;;
			webp)
				if [ "$SKIP_WEBP" = false ]; then
					# Reoptimize WebP (create temp file and replace if smaller)
					local temp_file="$(mktemp).webp"
					cwebp -quiet -mt -q "$WEBP_QUALITY" "$img" -o "$temp_file"
					if [ -f "$temp_file" ]; then
						local temp_size=$(get_file_size "$temp_file")
						if [ "$temp_size" -lt "$before_size" ]; then
							mv "$temp_file" "$img"
						else
							rm "$temp_file"
						fi
					fi
				fi
				;;
		esac
	fi
	
	local after_size=$(get_file_size "$img")
	local saved_size=$((before_size - after_size))
	local saved_percent=0
	
	if [ "$before_size" -ne 0 ]; then
		saved_percent=$((saved_size * 100 / before_size))
	fi
	
	TOTAL_FILES=$((TOTAL_FILES + 1))
	
	if [ "$before_size" -ne "$after_size" ] || [ "$DRY_RUN" = true ]; then
		if [ "$DRY_RUN" = true ]; then
			echo "SIMULATED (would save ~15%)"
			status="simulated"
			
			# In simulation, assume 15% savings for approximate statistics
			local simulated_size=$((before_size * 85 / 100))
			TOTAL_ORIGINAL=$((TOTAL_ORIGINAL + before_size))
			TOTAL_OPTIMIZED=$((TOTAL_OPTIMIZED + simulated_size))
			TOTAL_SAVED=$((TOTAL_SAVED + (before_size - simulated_size)))
			
			output="SIMULATED: $img (current size: $before_size bytes, estimated new size: $simulated_size bytes)"
		else
			echo "OPTIMIZED! $before_size -> $after_size bytes ($saved_percent% reduced)"
			status="optimized"
			
			TOTAL_ORIGINAL=$((TOTAL_ORIGINAL + before_size))
			TOTAL_OPTIMIZED=$((TOTAL_OPTIMIZED + after_size))
			TOTAL_SAVED=$((TOTAL_SAVED + saved_size))
			
			output="Optimized: $img ($before_size -> $after_size bytes, $saved_percent% reduced)"
		fi
	else
		echo "Already optimized"
		status="unchanged"
		
		# Still add the file size to totals
		TOTAL_ORIGINAL=$((TOTAL_ORIGINAL + before_size))
		TOTAL_OPTIMIZED=$((TOTAL_OPTIMIZED + after_size))
		
		output="Already optimized: $img"
	fi
	
	if [ "$ENABLE_LOG" = true ]; then
		echo "$output" >> "$LOG_FILE"
	fi
}

# Process images of a specific type
process_images() {
	local type="$1"
	local pattern="$2"
	
	# Skip disabled image types
	case "$type" in
		jpg|jpeg)
			if [ "$SKIP_JPG" = true ]; then
				log_message "Skipping processing of JPG/JPEG images" 2
				return
			fi
			;;
		png)
			if [ "$SKIP_PNG" = true ]; then
				log_message "Skipping processing of PNG images" 2
				return
			fi
			;;
		gif)
			if [ "$SKIP_GIF" = true ]; then
				log_message "Skipping processing of GIF images" 2
				return
			fi
			;;
		webp)
			if [ "$SKIP_WEBP" = true ] || [ "$WEBP_AVAILABLE" = false ]; then
				log_message "Skipping processing of WebP images" 2
				return
			fi
			;;
	esac
	
	log_message "Searching for $type images..." 1
	
	# Use recursive or non-recursive mode
	local find_cmd="find \"$IMAGES_DIR\""
	if [ "$RECURSIVE" = false ]; then
		find_cmd="$find_cmd -maxdepth 1"
	fi
	
	# First count total files for this type
	local total_files_for_type=$(eval "$find_cmd -type f -iname \"$pattern\"" | wc -l)
	if [ "$total_files_for_type" -eq 0 ]; then
		if [ "$VERBOSE" = true ]; then
			log_message "No $type images found in $IMAGES_DIR" 2
		fi
		return
	else
		log_message "Found $total_files_for_type $type images to process" 1
		
		# Display header for this image type section
		local separator="--------------------------------------"
		echo "$separator"
		echo "PROCESSING $type IMAGES ($total_files_for_type files)"
		echo "$separator"
	fi
	
	# Process files one by one - simple and reliable
	local file_count=0
	while IFS= read -r img; do
		# Skip if empty
		[ -z "$img" ] && continue
		
		# Update progress counter
		file_count=$((file_count + 1))
		
		# Show file number/total at the beginning of each line
		echo -n "[$file_count/$total_files_for_type] "
		
		# Process the image (will show detailed output)
		optimize_image "$img" "$type"
	done < <(eval "$find_cmd -type f -iname \"$pattern\"")
	
	# Show summary for this image type
	echo "$separator"
	echo "Completed processing $file_count $type images"
	echo ""
}

# Show statistics
show_stats() {
	if [ "$TOTAL_FILES" -gt 0 ]; then
		# Convert to MB for better readability
		local original_mb=$(echo "scale=2; $TOTAL_ORIGINAL/1048576" | bc)
		local optimized_mb=$(echo "scale=2; $TOTAL_OPTIMIZED/1048576" | bc)
		local saved_mb=$(echo "scale=2; $TOTAL_SAVED/1048576" | bc)
		local percent=0
		
		if [ "$TOTAL_ORIGINAL" -ne 0 ]; then
			percent=$(echo "scale=2; $TOTAL_SAVED*100/$TOTAL_ORIGINAL" | bc)
		fi
		
		local title="OPTIMIZATION SUMMARY ($DATE)"
		if [ "$DRY_RUN" = true ]; then
			title="OPTIMIZATION SIMULATION ($DATE)"
		fi
		
		local separator="======================================================"
		log_message "$separator" 1
		log_message "$title" 1
		log_message "${separator//?/-}" 1
		log_message "Directory: $IMAGES_DIR" 1
		log_message "Files processed: $TOTAL_FILES" 1
		log_message "Original size: $original_mb MB" 1
		log_message "Optimized size: $optimized_mb MB" 1
		log_message "Space saved: $saved_mb MB ($percent%)" 1
		
		if [ "$DRY_RUN" = true ]; then
			log_message "NOTE: This is a simulation (--dry-run), no changes were made" 1
		fi
		
		if [ "$VERBOSE" = true ]; then
			log_message "Configuration used:" 2
			log_message "- JPG quality: $JPG_QUALITY" 2
			log_message "- PNG level: $PNG_LEVEL" 2
			log_message "- WebP quality: $WEBP_QUALITY" 2
			log_message "- Recursive: $RECURSIVE" 2
		fi
		
		# Add estimated disk space savings
		if [ "$saved_mb" != "0.00" ]; then
			log_message "" 1
			if [ "$DRY_RUN" = true ]; then
				log_message "Potential disk space savings: $saved_mb MB" 1
			else
				log_message "Disk space saved: $saved_mb MB" 1
			fi
			
			# For non-dry runs, add some human-readable context to the savings
			if [ "$DRY_RUN" = false ]; then
				if (( $(echo "$saved_mb > 1000" | bc -l) )); then
					log_message "That's more than 1 GB of disk space saved!" 1
				elif (( $(echo "$saved_mb > 500" | bc -l) )); then
					log_message "That's half a GB of disk space saved!" 1
				elif (( $(echo "$saved_mb > 100" | bc -l) )); then
					log_message "That's a significant amount of disk space saved!" 1
				elif (( $(echo "$saved_mb > 10" | bc -l) )); then
					log_message "Every byte counts - good optimization!" 1
				fi
			fi
		fi
		
		log_message "$separator" 1
	else
		log_message "No images found to optimize" 1
	fi
}

# Main function
main() {
	# Process command line arguments
	parse_arguments "$@"
	
	# Prepare log file
	if [ "$ENABLE_LOG" = true ]; then
		# Create log directory if it doesn't exist
		LOG_DIR=$(dirname "$LOG_FILE")
		if [ ! -d "$LOG_DIR" ]; then
			mkdir -p "$LOG_DIR" 2>/dev/null
			if [ $? -ne 0 ]; then
				echo "Could not create log directory: $LOG_DIR"
				echo "Disabling logs..."
				ENABLE_LOG=false
			fi
		fi
		
		# Test writing to log file
		if [ "$ENABLE_LOG" = true ]; then
			touch "$LOG_FILE" 2>/dev/null
			if [ $? -ne 0 ]; then
				echo "Could not write to log file: $LOG_FILE"
				echo "Disabling logs..."
				ENABLE_LOG=false
			fi
		fi
	fi
	
	# Show execution mode
	if [ "$DRY_RUN" = true ]; then
		log_message "STARTING OPTIMIZATION SIMULATION ($DATE)" 1
		log_message "Simulation mode: No changes will be made to files" 1
	else
		log_message "STARTING IMAGE OPTIMIZATION ($DATE)" 1
	fi
	
	# Initial checks
	check_dependencies
	check_directory
	
	# Configuration information
	if [ "$VERBOSE" = true ]; then
		log_message "Directory: $IMAGES_DIR" 2
		log_message "Recursive: $RECURSIVE" 2
		log_message "Log file: $LOG_FILE" 2
		log_message "JPG quality: $JPG_QUALITY" 2
		log_message "PNG level: $PNG_LEVEL" 2
		log_message "WebP quality: $WEBP_QUALITY" 2
		
		# Show OS-specific information
		if [[ "$OSTYPE" == "darwin"* ]]; then
			log_message "Operating System: macOS" 2
		elif [ -f /etc/debian_version ]; then
			log_message "Operating System: Debian/Ubuntu" 2
		elif [ -f /etc/redhat-release ]; then
			log_message "Operating System: CentOS/RHEL" 2
		elif [ -f /etc/arch-release ]; then
			log_message "Operating System: Arch Linux" 2
		else
			log_message "Operating System: Linux (unknown distro)" 2
		fi
	fi
	
	# Reset counters
	TOTAL_ORIGINAL=0
	TOTAL_OPTIMIZED=0
	TOTAL_SAVED=0
	TOTAL_FILES=0
	
	# Show start time
	START_TIME=$(date +%s)
	
	# Process each image type
	process_images "jpg" "*.jpg"
	process_images "jpeg" "*.jpeg"
	process_images "png" "*.png"
	process_images "gif" "*.gif"
	process_images "webp" "*.webp"
	
	# Calculate elapsed time
	END_TIME=$(date +%s)
	ELAPSED_TIME=$((END_TIME - START_TIME))
	
	# Format time as minutes and seconds
	MINS=$((ELAPSED_TIME / 60))
	SECS=$((ELAPSED_TIME % 60))
	
	# Show statistics
	show_stats
	
	# Show completion message with time
	if [ "$DRY_RUN" = true ]; then
		log_message "SIMULATION COMPLETED in ${MINS}m ${SECS}s ($DATE)" 1
	else
		log_message "OPTIMIZATION COMPLETED in ${MINS}m ${SECS}s ($DATE)" 1
	fi
}

# Run the main program with received arguments
main "$@"
