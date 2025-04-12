# Image Optimizer Terminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![bash](https://img.shields.io/badge/language-bash-green.svg)](https://www.gnu.org/software/bash/)
[![Version](https://img.shields.io/badge/version-0.1_beta-blue.svg)](https://github.com/dcarrero/image-optimizer-terminal)

A powerful command-line tool to optimize images across any website, content management system, or local directory. While originally designed with WordPress in mind, this versatile script works equally well for any platform including Drupal, Joomla, static websites, or even personal photo collections.

Reduce file sizes, improve page loading speed, and boost your website's performance metrics like Largest Contentful Paint (LCP) — a critical factor for SEO and user experience.

## Why Use Image Optimizer Terminal?

- **No plugins required**: Works directly on the file system without installing additional software to your CMS
- **Server-level optimization**: Process images across multiple websites hosted on the same server
- **Complete control**: Fine-tune optimization settings for the perfect balance between quality and file size
- **Performance focus**: Significantly reduce page load times by optimizing image assets
- **Versatile application**: Works with any website, CMS, or directory containing images

## ⚠️ Important

**Always back up your files before running any automated optimization script.**

## Features

- **Multi-format support**: Optimizes JPG/JPEG, PNG, GIF, and WebP images
- **Recursive processing**: Automatically handles all subdirectories
- **Real-time feedback**: Shows detailed information for each optimized file
- **Comprehensive statistics**: Reports total space saved and optimization rates
- **Simulation mode**: Preview potential optimizations without modifying files
- **Customizable quality**: Set specific quality levels for each image format
- **Smart detection**: Automatically identifies system type and available tools
- **Wide compatibility**: Works on Debian/Ubuntu, CentOS/CloudLinux, RHEL, Arch Linux, and macOS

## Installation

### 1. Download the script

```bash
curl -O https://raw.githubusercontent.com/dcarrero/image-optimizer-terminal/main/optimize-images.sh
chmod +x optimize-images.sh
```

### 2. Install required dependencies

#### On Debian/Ubuntu:
```bash
sudo apt update && sudo apt install jpegoptim optipng gifsicle webp bc
```

#### On CentOS/RHEL/CloudLinux:
```bash
sudo yum install epel-release
sudo yum install jpegoptim optipng gifsicle bc
```
Note: WebP tools aren't available in standard CentOS repositories but the script will work without them.

#### On Arch Linux:
```bash
sudo pacman -S jpegoptim optipng gifsicle webp bc
```

#### On macOS (using Homebrew):
```bash
brew install jpegoptim optipng gifsicle webp coreutils bc
```

## Usage

### Basic usage
```bash
./optimize-images.sh -d /path/to/your/images
```

### Common Examples

#### Optimize WordPress uploads directory
```bash
./optimize-images.sh -d /var/www/html/wp-content/uploads
```

#### Optimize a Drupal site's image directory
```bash
./optimize-images.sh -d /var/www/html/sites/default/files
```

#### Process a static website's image assets
```bash
./optimize-images.sh -d /var/www/html/assets/images
```

#### Optimize your personal photo collection
```bash
./optimize-images.sh -d ~/Pictures/vacation2024
```

#### Dry run (no changes, just show what would happen)
```bash
./optimize-images.sh --dry-run -d /path/to/images
```

#### Set specific quality levels
```bash
./optimize-images.sh -d ./photos --jpg-quality 90 --png-level 2
```

#### Process current directory without subdirectories
```bash
./optimize-images.sh --no-recursive
```

#### Skip certain image formats
```bash
./optimize-images.sh -d ./images --skip-gif --skip-webp
```

### All available options

```
Usage: optimize-images.sh [OPTIONS]

Script to optimize images (JPG, JPEG, PNG, GIF, WebP) for websites and image collections.

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
```

## Setting up as a Cron Job

To run the script automatically at scheduled intervals, add a cron job:

```bash
# Edit your crontab
crontab -e

# Add a line like this to run daily at 3 AM:
0 3 * * * /path/to/optimize-images.sh -d /path/to/image/directory --quiet
```

This is particularly useful for:
- Regularly optimizing newly uploaded content
- Maintaining optimal performance on high-traffic websites
- Processing large image collections over time

## How it Works

The script works by:

1. Finding all supported image files in the specified directory (and subdirectories if recursive)
2. Using specialized optimization tools for each format:
   - `jpegoptim` for JPG/JPEG optimization
   - `optipng` for PNG optimization
   - `gifsicle` for GIF optimization
   - `cwebp` for WebP optimization (when available)
3. Optimizing each image while preserving quality based on user-defined settings
4. Providing detailed statistics on space saved

## Output Example

```
Searching for jpg images...
Found 3 jpg images to process
--------------------------------------
PROCESSING jpg IMAGES (3 files)
--------------------------------------
[1/3] Processing: image1.jpg (jpg, 1245678 bytes)... OPTIMIZED! 1245678 -> 934260 bytes (25% reduced)
[2/3] Processing: image2.jpg (jpg, 567890 bytes)... Already optimized
[3/3] Processing: image3.jpg (jpg, 890123 bytes)... OPTIMIZED! 890123 -> 712098 bytes (20% reduced)
--------------------------------------
Completed processing 3 jpg images

[Additional image formats processed...]

======================================================
OPTIMIZATION SUMMARY (2025-04-12 18:30:45)
------------------------------------------------------
Directory: /path/to/images
Files processed: 5
Original size: 2.71 MB
Optimized size: 2.09 MB
Space saved: 0.62 MB (22.99%)

Disk space saved: 0.62 MB
Every byte counts - good optimization!
======================================================
OPTIMIZATION COMPLETED in 0m 3s (2025-04-12 18:30:45)
```

## Performance Benefits

Using the Image Optimizer Terminal can lead to significant performance improvements:

- **Faster page loads**: Reduced image sizes mean quicker downloads for visitors
- **Lower bandwidth usage**: Save on hosting costs and improve mobile experience
- **Better SEO scores**: Improved Core Web Vitals metrics like LCP
- **Reduced storage requirements**: Save disk space on your server

## Compatibility

The script has been tested on:
- Ubuntu/Debian-based systems
- CentOS/CloudLinux/RHEL
- Arch Linux
- macOS (requires coreutils package from Homebrew)

## Troubleshooting

- If you get permission errors, make sure you have write access to the image directory or run with `--dry-run` to test
- If certain file types are not optimized, check if the corresponding optimization tool is installed
- For very large directories with many images, the script may take a long time to complete
- When running as a cron job, use absolute paths to both the script and the image directory

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

- David Carrero Fernández-Baillo <dcarrero@stackscale.com>
- Website: [carrero.es](https://carrero.es)
- Twitter/X: [@carrero](https://twitter.com/carrero)
- GitHub: [dcarrero](https://github.com/dcarrero)
