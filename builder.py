#!/usr/bin/env python3
"""
builder.py

This script builds new car folders in the Build directory based on the car folders found in the Source directory.
It does the following:

1. Checks whether a Build folder already exists. If so and it contains files,
   it warns the user and asks for confirmation to delete it.
2. For every car folder (i.e. any folder not named "data") in the adjacent Source folder:
   - Creates a folder in Build with the car folder's name.
   - Copies the global data (from Source/data) into a "data" subfolder in the new car folder.
   - Copies all other files and folders (skipping any "data" item) from the source car folder into the new built car folder.
   - Renames "model.kn5" in the new car folder to "[CAR_FOLDER_NAME].kn5".
   - Edits the "lods.ini" file in the built car folder's data directory so that under the "[LOD_0]" group the line
     "FILE=" is set to the new kn5 filename.

Options:
   --pack-release: Create a release zip file from the Build folder contents.
     
Note: This script requires Python 3.8+ for the use of shutil.copytree(..., dirs_exist_ok=True).
"""

import os
import shutil
import sys
import json
from datetime import datetime
import fnmatch
from typing import List, Optional
import configparser
import subprocess
import tempfile
import argparse
import zipfile

try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib
    except ImportError:
        print("Please install tomli or use Python 3.11+ for tomllib support.")
        sys.exit(1)

def confirm_deletion(build_dir):
    """
    Checks if the build_dir is non-empty (recursively) and, if so, asks for user confirmation
    to delete it.
    Returns True if deletion is confirmed (or the folder is empty).
    """
    for root, dirs, files in os.walk(build_dir):
        if files:
            return input(
                f"Warning: '{build_dir}' already exists and contains files. Do you want to delete it and continue? (y/N): "
            ).strip().lower() == 'y'
    return True

def update_lods_ini(lods_ini_path, kn5_filename):
    """
    Reads lods.ini, finds the [LOD_0] section and replaces the first "FILE=" line with:
      FILE=<kn5_filename>
    Then writes the file back.
    """
    try:
        with open(lods_ini_path, "r") as f:
            lines = f.readlines()

        in_lod0 = False
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped == "[LOD_0]":
                in_lod0 = True
            elif stripped.startswith("["):
                in_lod0 = False
            elif in_lod0 and stripped.startswith("FILE="):
                lines[i] = f"FILE={kn5_filename}\n"

        with open(lods_ini_path, "w") as f:
            f.writelines(lines)
        print(f"Updated lods.ini in {os.path.dirname(lods_ini_path)}")
    except Exception as e:
        print(f"Failed to write {lods_ini_path}: {e}")

def should_ignore_file(path: str, ignore_patterns: List[str]) -> bool:
    """
    Check if a file should be ignored based on the ignore patterns.
    Supports exact matches, wildcards (*), and path-aware patterns (**).
    
    Args:
        path: The file/folder path to check
        ignore_patterns: List of ignore patterns from info.toml
    
    Returns:
        bool: True if the file should be ignored
    """
    # Convert Windows paths to forward slashes for consistent matching
    path = path.replace('\\', '/')
    
    # Get just the filename for simple pattern matching
    filename = os.path.basename(path)
    
    for pattern in ignore_patterns:
        # Convert Windows patterns to forward slashes
        pattern = pattern.replace('\\', '/')
        
        # Handle path-aware patterns (with **)
        if '**' in pattern:
            # Convert ** to handle any number of directories
            regex_pattern = pattern.replace('**', '.*').replace('*', '[^/]*')
            if fnmatch.fnmatch(path, regex_pattern):
                return True
        # Handle simple patterns (exact matches and wildcards)
        elif fnmatch.fnmatch(filename, pattern):
            return True
    
    return False

def parse_info_toml(toml_path):
    """
    Parse info.toml for version, year, and ignore patterns.
    """
    try:
        with open(toml_path, "rb") as f:
            data = tomllib.load(f)
        info = data.get("info", {})
        version = info.get("version")
        year = info.get("year")
        
        # Get ignore patterns, defaulting to just ~* if not specified
        build_config = data.get("build", {})
        ignore_patterns = build_config.get("ignore", ["~*"])
        
        return version, year, ignore_patterns
    except Exception as e:
        print(f"Error parsing {toml_path}: {e}")
        return None, None, ["~*"]

def update_ui_json(ui_json_path, version, year):
    """
    Loads the ui/ui_car.json file, updates its 'version' and 'year',
    and appends a timestamp to the 'description' field.
    """
    try:
        with open(ui_json_path, "r") as f:
            data = json.load(f)
    except Exception as e:
        print(f"Failed to load {ui_json_path}: {e}")
        return

    data["version"] = version
    data["year"] = year
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    append_text = f"<br><br>Car compiled on {now_str}."
    if "description" in data and isinstance(data["description"], str):
        data["description"] += append_text
    else:
        data["description"] = append_text.strip()

    try:
        with open(ui_json_path, "w") as f:
            json.dump(data, f, indent=4)
        print(f"Updated ui_car.json at {ui_json_path}")
    except Exception as e:
        print(f"Failed to write {ui_json_path}: {e}")

def update_guids_txt(guids_path, old_name, new_name):
    """
    Updates the GUIDs.txt file, replacing all occurrences of the old bank name
    with the new bank name in both bank:/ references and event:/cars/ paths.
    """
    try:
        with open(guids_path, 'r') as f:
            content = f.read()
        
        # Replace both the bank reference and event paths
        updated_content = content.replace(f"bank:/{old_name}", f"bank:/{new_name}")
        updated_content = updated_content.replace(f"event:/cars/{old_name}/", f"event:/cars/{new_name}/")
        
        with open(guids_path, 'w') as f:
            f.write(updated_content)
        print(f"Updated bank and event references in GUIDs.txt from '{old_name}' to '{new_name}'")
    except Exception as e:
        print(f"Error updating GUIDs.txt: {e}")

def handle_sfx_files(car_build_dir, car_name):
    """
    Special handling for sfx files:
    1. Rename the .bank file to match the car name
    2. Update references in GUIDs.txt
    """
    sfx_dir = os.path.join(car_build_dir, "sfx")
    if not os.path.exists(sfx_dir):
        return
    
    # Find and rename the .bank file
    for file in os.listdir(sfx_dir):
        if file.endswith(".bank"):
            old_bank_path = os.path.join(sfx_dir, file)
            new_bank_name = f"{car_name}.bank"
            new_bank_path = os.path.join(sfx_dir, new_bank_name)
            
            try:
                os.rename(old_bank_path, new_bank_path)
                print(f"Renamed sfx bank file from '{file}' to '{new_bank_name}'")
                
                # Update GUIDs.txt
                guids_path = os.path.join(sfx_dir, "GUIDs.txt")
                if os.path.exists(guids_path):
                    old_name = os.path.splitext(file)[0]
                    update_guids_txt(guids_path, old_name, car_name)
            except Exception as e:
                print(f"Error handling sfx files: {e}")
            break

def merge_ini_files(base_ini_path, addon_ini_path, output_path):
    """
    Merge an addon INI file into a base INI file.
    The addon INI can contain partial sections that will override
    corresponding sections in the base INI.
    If a section contains only a single 'DELETE=1' key,
    the entire section will be removed from the base INI.
    """
    try:
        # Create parsers for both files
        base_config = configparser.ConfigParser()
        addon_config = configparser.ConfigParser()
        
        # Preserve case sensitivity and allow duplicate keys
        base_config.optionxform = str
        addon_config.optionxform = str
        
        # Read the base INI file
        base_config.read(base_ini_path, encoding='utf-8')
        
        # Read the addon INI file
        addon_config.read(addon_ini_path, encoding='utf-8')
        
        # Process addon sections
        for section_name in addon_config.sections():
            section_items = list(addon_config.items(section_name))
            
            # Check if this section should be deleted
            if (len(section_items) == 1 and 
                section_items[0][0].upper() == 'DELETE' and 
                section_items[0][1] == '1'):
                
                # Remove the section from base config if it exists
                if base_config.has_section(section_name):
                    base_config.remove_section(section_name)
                    print(f"Deleted section [{section_name}] from base INI")
                continue
            
            # Normal merge logic for non-DELETE sections
            if not base_config.has_section(section_name):
                # If section doesn't exist in base, add it entirely
                base_config.add_section(section_name)
            
            # Override/add all options from addon section
            for option_name, option_value in addon_config.items(section_name):
                base_config.set(section_name, option_name, option_value)
        
        # Write the merged result
        with open(output_path, 'w', encoding='utf-8') as f:
            base_config.write(f, space_around_delimiters=False)
        
        print(f"Merged INI: {os.path.basename(addon_ini_path)} -> {os.path.basename(output_path)}")
        
    except Exception as e:
        print(f"Error merging INI files {base_ini_path} + {addon_ini_path}: {e}")

def merge_directories(src, dst, ignore_patterns):
    """
    Recursively merge contents of src directory into dst directory.
    Files from src will overwrite those in dst.
    Skips files matching ignore patterns.
    Special handling for .addon.ini files which are merged with their base INI files.
    """
    if not os.path.exists(dst):
        os.makedirs(dst)
    
    # First pass: collect .addon.ini files for processing
    addon_files = {}
    regular_files = []
    
    for item in os.listdir(src):
        s_item = os.path.join(src, item)
        if should_ignore_file(s_item, ignore_patterns):
            print(f"Skipping ignored file/folder '{item}'")
            continue
        
        if item.endswith('.addon.ini'):
            # Map addon file to its base name
            base_name = item.replace('.addon.ini', '.ini')
            addon_files[base_name] = s_item
        else:
            regular_files.append(item)
    
    # Second pass: process regular files and handle INI merging
    for item in regular_files:
        s_item = os.path.join(src, item)
        d_item = os.path.join(dst, item)
        
        try:
            if os.path.isdir(s_item):
                if not os.path.exists(d_item):
                    shutil.copytree(s_item, d_item)
                    print(f"Copied new folder '{item}' from source merge.")
                else:
                    merge_directories(s_item, d_item, ignore_patterns)
            else:
                # Check if this file has a corresponding .addon.ini file
                if item.endswith('.ini') and item in addon_files:
                    # This is a base INI file with an addon - merge them
                    addon_path = addon_files[item]
                    merge_ini_files(s_item, addon_path, d_item)
                else:
                    # Regular file copy
                    shutil.copy2(s_item, d_item)
                    print(f"Overwritten file '{item}' from source merge.")
        except Exception as e:
            print(f"Error merging {s_item} into {d_item}: {e}")
    
    # Third pass: handle .addon.ini files that don't have corresponding base files
    for base_name, addon_path in addon_files.items():
        base_exists_in_src = os.path.exists(os.path.join(src, base_name))
        base_exists_in_dst = os.path.exists(os.path.join(dst, base_name))
        
        if not base_exists_in_src and base_exists_in_dst:
            # Addon file exists but no base file in src - merge with existing dst file
            d_item = os.path.join(dst, base_name)
            try:
                merge_ini_files(d_item, addon_path, d_item)
            except Exception as e:
                print(f"Error merging addon {addon_path} with existing {d_item}: {e}")
        elif not base_exists_in_src and not base_exists_in_dst:
            # No base file anywhere - treat addon as the complete file
            d_item = os.path.join(dst, base_name)
            try:
                shutil.copy2(addon_path, d_item)
                print(f"Copied addon file '{os.path.basename(addon_path)}' as '{base_name}' (no base file found)")
            except Exception as e:
                print(f"Error copying addon file {addon_path}: {e}")

def pack_data_folder(car_build_dir, car_name):
    """
    Uses QuickBMS with the rebuilder script to pack the data folder into data.acd,
    then deletes the original data folder.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    quickbms_path = os.path.join(script_dir, "quickbms.exe")
    rebuilder_script = os.path.join(script_dir, "assetto_corsa_acd_rebuilder.bms")
    data_dir = os.path.join(car_build_dir, "data")
    
    # Check if QuickBMS and the rebuilder script exist
    if not os.path.exists(quickbms_path):
        print(f"Warning: QuickBMS not found at {quickbms_path}. Skipping data packing for {car_name}")
        return False
    
    if not os.path.exists(rebuilder_script):
        print(f"Warning: Rebuilder script not found at {rebuilder_script}. Skipping data packing for {car_name}")
        return False
    
    if not os.path.exists(data_dir):
        print(f"Warning: Data folder not found for {car_name}. Skipping data packing.")
        return False
    
    try:
        # Create a simple temp directory structure
        with tempfile.TemporaryDirectory() as temp_base:
            # Create the car folder structure
            temp_car_dir = os.path.join(temp_base, car_name)
            os.makedirs(temp_car_dir)
            
            # Copy data folder contents directly to the car folder (not in a data subfolder)
            print(f"Copying data files to temporary location: {temp_car_dir}")
            for item in os.listdir(data_dir):
                src_item = os.path.join(data_dir, item)
                dst_item = os.path.join(temp_car_dir, item)
                if os.path.isfile(src_item):
                    shutil.copy2(src_item, dst_item)
                else:
                    shutil.copytree(src_item, dst_item)
            
            # Create a minimal dummy data.acd file
            temp_acd = os.path.join(temp_car_dir, "data.acd")
            with open(temp_acd, 'wb') as f:
                f.write(b'\x00' * 16)  # Create minimal dummy file
            
            # Run QuickBMS directly in the car folder
            cmd = [
                quickbms_path,
                rebuilder_script,
                "data.acd",
                "."
            ]
            
            print(f"Packing data folder for {car_name}...")
            print(f"Command: {' '.join(cmd)} (in directory: {temp_car_dir})")
            
            # Change working directory to the temp car folder
            original_cwd = os.getcwd()
            os.chdir(temp_car_dir)
            
            try:
                result = subprocess.run(cmd, capture_output=True, text=True)
            finally:
                # Always restore original working directory
                os.chdir(original_cwd)
            
            # Print QuickBMS output for debugging
            if result.stdout:
                print("QuickBMS stdout:")
                print(result.stdout)
            if result.stderr:
                print("QuickBMS stderr:")
                print(result.stderr)
            
            if result.returncode == 0:
                # Look for the generated .rebuilt file
                rebuilt_files = []
                for root, dirs, files in os.walk(temp_base):
                    for file in files:
                        if file.endswith('.rebuilt'):
                            rebuilt_files.append(os.path.join(root, file))
                
                if rebuilt_files:
                    # Move the .rebuilt file to data.acd in the original location
                    rebuilt_file = rebuilt_files[0]
                    final_acd = os.path.join(car_build_dir, "data.acd")
                    shutil.move(rebuilt_file, final_acd)
                    
                    # Remove the original data folder
                    shutil.rmtree(data_dir)
                    
                    print(f"Successfully packed data folder for {car_name} -> data.acd")
                    return True
                else:
                    print(f"Error: No .rebuilt file generated for {car_name}")
                    return False
            else:
                print(f"Error packing data for {car_name}: QuickBMS returned code {result.returncode}")
                return False
                
    except Exception as e:
        print(f"Error packing data folder for {car_name}: {e}")
        return False

def debug_directory_scan(data_dir):
    """
    Debug function to see what files are actually in the directory
    and test if there are any problematic files.
    """
    print(f"DEBUG: Scanning directory {data_dir}")
    try:
        files = os.listdir(data_dir)
        print(f"DEBUG: Found {len(files)} items")
        
        for file in sorted(files):
            file_path = os.path.join(data_dir, file)
            try:
                if os.path.isfile(file_path):
                    size = os.path.getsize(file_path)
                    # Check for non-ASCII characters
                    try:
                        file.encode('ascii')
                        ascii_ok = "✓"
                    except UnicodeEncodeError:
                        ascii_ok = "✗ (non-ASCII)"
                    
                    print(f"  FILE: {file} ({size} bytes) {ascii_ok}")
                else:
                    print(f"  DIR:  {file}/")
            except Exception as e:
                print(f"  ERROR: {file} - {e}")
                
        # Check for hidden files on Windows
        try:
            import subprocess
            result = subprocess.run(['dir', '/a', data_dir], 
                                  capture_output=True, text=True, shell=True)
            hidden_files = [line for line in result.stdout.split('\n') 
                          if 'ro.ini' in line.lower()]
            if hidden_files:
                print(f"DEBUG: Found ro.ini references in dir output:")
                for line in hidden_files:
                    print(f"  {line.strip()}")
        except:
            pass
            
    except Exception as e:
        print(f"DEBUG: Error scanning directory: {e}")

def pack_release_zip(script_dir, build_dir, project_name, version):
    """
    Creates a release zip file from the Build folder contents.
    The zip structure will be content/cars/each_car_folder.
    Also includes LICENSE.txt if it exists.
    """
    if not os.path.exists(build_dir):
        print(f"Build directory not found: {build_dir}")
        return False
    
    # Create the zip filename
    zip_filename = f"{project_name} v{version}.zip"
    zip_path = os.path.join(script_dir, zip_filename)
    
    print(f"Creating release zip: {zip_filename}")
    
    try:
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            # Add each car folder to content/cars/
            for item in os.listdir(build_dir):
                item_path = os.path.join(build_dir, item)
                if os.path.isdir(item_path):
                    car_name = item
                    print(f"Adding car '{car_name}' to release zip...")
                    
                    # Add all files in the car folder
                    for root, dirs, files in os.walk(item_path):
                        for file in files:
                            file_path = os.path.join(root, file)
                            # Calculate the relative path from the car folder
                            rel_path = os.path.relpath(file_path, item_path)
                            # Create the zip path as content/cars/car_name/rel_path
                            zip_path_in_archive = f"content/cars/{car_name}/{rel_path}".replace('\\', '/')
                            zipf.write(file_path, zip_path_in_archive)
            
            # Add LICENSE.txt if it exists
            license_path = os.path.join(script_dir, "LICENSE.txt")
            if os.path.exists(license_path):
                zipf.write(license_path, "LICENSE.txt")
                print("Added LICENSE.txt to release zip")
            else:
                print("Warning: LICENSE.txt not found, skipping")
        
        print(f"Release zip created successfully: {zip_path}")
        return True
        
    except Exception as e:
        print(f"Error creating release zip: {e}")
        return False

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Build car folders and optionally create release packages')
    parser.add_argument('--pack-release', action='store_true', 
                       help='Create a release zip file from the Build folder contents')
    args = parser.parse_args()
    
    # Get the directory in which the script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_dir = os.path.join(script_dir, "Source")
    build_dir = os.path.join(script_dir, "Build")
    
    # Parse info.toml from the Source folder
    info_toml_path = os.path.join(source_dir, "info.toml")
    if not os.path.exists(info_toml_path):
        print(f"info.toml not found in {source_dir}")
        sys.exit(1)
    info_version, info_year, ignore_patterns = parse_info_toml(info_toml_path)
    
    # Also get the project name for release packaging
    try:
        with open(info_toml_path, "rb") as f:
            data = tomllib.load(f)
        info = data.get("info", {})
        project_name = info.get("project", "Unknown Project")
    except Exception as e:
        print(f"Error getting project name from {info_toml_path}: {e}")
        project_name = "Unknown Project"
    
    if not info_version or not info_year:
        print("Could not parse version and year from info.toml")
        sys.exit(1)
    
    # If --pack-release is specified, create release zip and exit
    if args.pack_release:
        if pack_release_zip(script_dir, build_dir, project_name, info_version):
            print("Release packaging complete.")
        else:
            print("Release packaging failed.")
            sys.exit(1)
        return
    
    # Ensure Source folder exists
    if not os.path.exists(source_dir):
        print(f"Source directory not found: {source_dir}")
        sys.exit(1)
    
    # Get the global base folder from Source/base
    global_base_dir = os.path.join(source_dir, "base")
    if not os.path.exists(global_base_dir):
        print(f"Global base folder not found: {global_base_dir}")
        sys.exit(1)
    
    # Handle an existing Build directory (delete with prompt if non-empty)
    if os.path.exists(build_dir):
        if not confirm_deletion(build_dir):
            print("Build process cancelled.")
            sys.exit(0)
        try:
            shutil.rmtree(build_dir)
            print(f"Deleted existing '{build_dir}' folder.")
        except Exception as e:
            print(f"Error deleting {build_dir}: {e}")
            sys.exit(1)
    
    # Create a fresh Build directory
    os.makedirs(build_dir)
    print(f"Created Build folder at '{build_dir}'")
    
    # Process each car folder in Source (skip the "base" folder)
    for item in os.listdir(source_dir):
        item_path = os.path.join(source_dir, item)
        if os.path.isdir(item_path) and item.lower() != "base":
            car_name = item
            print(f"\nProcessing car: {car_name}")
            # Create a new folder for the car in Build
            car_build_dir = os.path.join(build_dir, car_name)
            os.makedirs(car_build_dir, exist_ok=True)
            
            # Copy global base folder contents into the car build folder
            try:
                for base_item in os.listdir(global_base_dir):
                    src_item = os.path.join(global_base_dir, base_item)
                    if should_ignore_file(src_item, ignore_patterns):
                        print(f"Skipping ignored file/folder '{base_item}'")
                        continue
                        
                    dst_item = os.path.join(car_build_dir, base_item)
                    if os.path.isdir(src_item):
                        shutil.copytree(src_item, dst_item, dirs_exist_ok=True)
                        print(f"Copied folder '{base_item}' from base into '{car_name}'")
                    else:
                        shutil.copy2(src_item, dst_item)
                        print(f"Copied file '{base_item}' from base into '{car_name}'")
            except Exception as e:
                print(f"Error copying base folder contents for {car_name}: {e}")
                continue
            
            # Copy all other files and folders from the car's source folder
            for sub_item in os.listdir(item_path):
                src_item = os.path.join(item_path, sub_item)
                if should_ignore_file(src_item, ignore_patterns):
                    print(f"Skipping ignored file/folder '{sub_item}'")
                    continue
                    
                dst_item = os.path.join(car_build_dir, sub_item)
                try:
                    if os.path.isdir(src_item):
                        merge_directories(src_item, dst_item, ignore_patterns)
                        print(f"Merged folder '{sub_item}' for {car_name}")
                    else:
                        shutil.copy2(src_item, dst_item)
                        print(f"Copied file '{sub_item}' for {car_name}")
                except Exception as e:
                    print(f"Error copying {src_item} for {car_name}: {e}")
            
            # Rename model.kn5 to [CAR_FOLDER_NAME].kn5 in the car build folder
            model_kn5_path = os.path.join(car_build_dir, "model.kn5")
            new_kn5_name = f"{car_name}.kn5"
            new_kn5_path = os.path.join(car_build_dir, new_kn5_name)
            if os.path.exists(model_kn5_path):
                try:
                    os.rename(model_kn5_path, new_kn5_path)
                    print(f"Renamed 'model.kn5' to '{new_kn5_name}'")
                except Exception as e:
                    print(f"Error renaming model.kn5 for {car_name}: {e}")
            else:
                print(f"Warning: 'model.kn5' not found for {car_name}")
            
            # After copying all files but before updating lods.ini, handle sfx files
            handle_sfx_files(car_build_dir, car_name)
            
            # Update lods.ini in the built car folder.
            lods_ini_path = os.path.join(car_build_dir, "data", "lods.ini")
            if os.path.exists(lods_ini_path):
                update_lods_ini(lods_ini_path, new_kn5_name)
            else:
                print(f"Warning: 'lods.ini' not found in '{car_build_dir}' for {car_name}")
            
            # Update ui/ui_car.json in the built car folder.
            ui_json_path = os.path.join(car_build_dir, "ui", "ui_car.json")
            if os.path.exists(ui_json_path):
                update_ui_json(ui_json_path, info_version, info_year)
            else:
                print(f"Warning: 'ui/ui_car.json' not found for {car_name}")
            
            # Pack the data folder into data.acd
            pack_data_folder(car_build_dir, car_name)
    
    print("\nBuild process complete.")

if __name__ == "__main__":
    main()
