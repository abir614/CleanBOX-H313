#!/usr/bin/env python3
"""
CleanBOX-H313 Bootloader Splash Patch Utility
Replaces static OEM boot logos in Allwinner H313 FAT16 bootloader partitions
(e.g., /dev/block/by-name/bootloader -> mmcblk0p1).
"""

import sys, os, struct, argparse

def patch_bootloader(image_path, splash_bmp_path, output_path, target_names=["BOOTLOGOBMP", "TX9PRO  BMP"]):
    print(f"[*] Reading bootloader image: {image_path}")
    with open(image_path, "rb") as f:
        img_data = bytearray(f.read())
    
    with open(splash_bmp_path, "rb") as f:
        splash_data = f.read()

    # Basic BMP validation
    if splash_data[:2] != b"BM":
        raise ValueError("Invalid BMP file: missing 'BM' magic header.")
    
    bmp_size = len(splash_data)
    print(f"[*] Splash bitmap size: {bmp_size} bytes")

    # Read FAT boot sector
    bytes_per_sec = int.from_bytes(img_data[11:13], "little")
    sec_per_clus = img_data[13]
    reserved_sec = int.from_bytes(img_data[14:16], "little")
    num_fats = img_data[16]
    root_entries = int.from_bytes(img_data[17:19], "little")
    fat_size16 = int.from_bytes(img_data[22:24], "little")

    cluster_size = bytes_per_sec * sec_per_clus
    root_dir_offset = (reserved_sec + num_fats * fat_size16) * bytes_per_sec
    root_dir_size = root_entries * 32
    data_offset = root_dir_offset + root_dir_size

    print(f"[*] FAT16 geometry: {bytes_per_sec} B/sec, {sec_per_clus} sec/clus, Data offset={data_offset}")

    targets_patched = 0
    for i in range(root_entries):
        entry_off = root_dir_offset + i * 32
        entry = img_data[entry_off : entry_off + 32]
        if entry[0] in (0x00, 0xE5) or entry[11] == 0x0F:
            continue
        
        name = entry[0:11].decode("latin1", errors="replace")
        cluster = int.from_bytes(entry[26:28], "little")
        file_size = int.from_bytes(entry[28:32], "little")

        for target in target_names:
            norm_target = target.replace(" ", "").upper()
            norm_name = name.replace(" ", "").upper()
            if norm_name == norm_target:
                file_offset = data_offset + (cluster - 2) * cluster_size
                print(f"[+] Found target {name.strip()} at cluster {cluster} (offset {file_offset}, size {file_size})")
                
                # Check byte boundary
                write_size = min(bmp_size, file_size)
                img_data[file_offset : file_offset + write_size] = splash_data[:write_size]
                targets_patched += 1
                print(f"    -> Patched {write_size} bytes into {name.strip()}")

    if targets_patched == 0:
        print("[-] Warning: No matching targets found in root directory!")
    else:
        print(f"[+] Successfully patched {targets_patched} target(s).")
        with open(output_path, "wb") as f:
            f.write(img_data)
        print(f"[+] Wrote patched bootloader image to {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CleanBOX H313 Bootloader Splash Patch Tool")
    parser.add_argument("bootloader_img", help="Path to input bootloader.img")
    parser.add_argument("splash_bmp", help="Path to CleanBOX splash .bmp file (1280x720 24-bit)")
    parser.add_argument("output_img", help="Path to output patched bootloader.img")
    parser.add_argument("--targets", nargs="+", default=["BOOTLOGOBMP", "TX9PRO  BMP"], help="Target 8.3 filenames to patch")
    args = parser.parse_args()
    patch_bootloader(args.bootloader_img, args.splash_bmp, args.output_img, args.targets)
