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
     
Note: This script requires Python 3.8+ for the use of shutil.copytree(..., dirs_exist_ok=True).
"""

import os
import shutil
import sys
import json
from datetime import datetime

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

def parse_info_toml(toml_path):
    """
    A simple parser to extract 'version' and 'year' from the [info] section in the toml file.
    """
    try:
        with open(toml_path, "rb") as f:
            data = tomllib.load(f)
        info = data.get("info", {})
        version = info.get("version")
        year = info.get("year")
        return version, year
    except Exception as e:
        print(f"Error parsing {toml_path}: {e}")
        return None, None

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
    append_text = f" Car compiled on {now_str}."
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

def merge_directories(src, dst):
    """
    Recursively merge contents of src directory into dst directory.
    Files from src will overwrite those in dst.
    """
    if not os.path.exists(dst):
        os.makedirs(dst)
    for item in os.listdir(src):
        s_item = os.path.join(src, item)
        d_item = os.path.join(dst, item)
        try:
            if os.path.isdir(s_item):
                if not os.path.exists(d_item):
                    shutil.copytree(s_item, d_item)
                    print(f"Copied new folder '{item}' from source merge.")
                else:
                    merge_directories(s_item, d_item)
            else:
                shutil.copy2(s_item, d_item)
                print(f"Overwritten file '{item}' from source merge.")
        except Exception as e:
            print(f"Error merging {s_item} into {d_item}: {e}")

def main():
    # Get the directory in which the script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_dir = os.path.join(script_dir, "Source")
    build_dir = os.path.join(script_dir, "Build")
    
    # Ensure Source folder exists
    if not os.path.exists(source_dir):
        print(f"Source directory not found: {source_dir}")
        sys.exit(1)
    
    # Parse info.toml from the Source folder for version and year
    info_toml_path = os.path.join(source_dir, "info.toml")
    if not os.path.exists(info_toml_path):
        print(f"info.toml not found in {source_dir}")
        sys.exit(1)
    info_version, info_year = parse_info_toml(info_toml_path)
    if not info_version or not info_year:
        print("Could not parse version and year from info.toml")
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
            
            # Copy all other files and folders from the car's source folder,
            # merging them over the base so that car-specific files override the base.
            for sub_item in os.listdir(item_path):
                src_item = os.path.join(item_path, sub_item)
                dst_item = os.path.join(car_build_dir, sub_item)
                try:
                    if os.path.isdir(src_item):
                        merge_directories(src_item, dst_item)
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
    
    print("\nBuild process complete.")

if __name__ == "__main__":
    main()
