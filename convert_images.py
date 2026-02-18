import os
import rawpy
from PIL import Image
import concurrent.futures
import numpy as np
import json

def convert_cr3_to_jpg(input_path, output_path, max_width=1600):
   if os.path.exists(output_path):
       print(f"Skipping {output_path}, already exists.")
       return True

   try:
       with rawpy.imread(input_path) as raw:
           rgb = raw.postprocess()
       
       # Convert numpy array to PIL Image for resizing
       img = Image.fromarray(rgb)
       
       # Calculate new height to maintain aspect ratio
       width_percent = (max_width / float(img.size[0]))
       new_height = int((float(img.size[1]) * float(width_percent)))
       
       img = img.resize((max_width, new_height), Image.Resampling.LANCZOS)
       
       # Save as JPG
       img.save(output_path, "JPEG", quality=85)
       print(f"Converted: {input_path} -> {output_path}")
       return True
   except Exception as e:
       print(f"Failed to convert {input_path}: {e}")
       return False

def main():
   image_dir = "images"
   output_dir = os.path.join(image_dir, "jpg")
   
   if not os.path.exists(output_dir):
       os.makedirs(output_dir)
       
   tasks = []
   
   with concurrent.futures.ProcessPoolExecutor() as executor:
       for filename in os.listdir(image_dir):
           if filename.lower().endswith(".cr3"):
               input_path = os.path.join(image_dir, filename)
               output_filename = os.path.splitext(filename)[0] + ".jpg"
               output_path = os.path.join(output_dir, output_filename)
               
               tasks.append(executor.submit(convert_cr3_to_jpg, input_path, output_path))
   
   # Wait for all tasks to complete
   for future in concurrent.futures.as_completed(tasks):
       future.result()
       
   # Generate gallery.json from the output directory
   if os.path.exists(output_dir):
       jpg_files = [f for f in os.listdir(output_dir) if f.lower().endswith('.jpg')]
       jpg_files.sort()
       
       with open('gallery.json', 'w') as f:
           json.dump(jpg_files, f)
       print(f"Generated gallery.json with {len(jpg_files)} images.")
   else:
       print("No jpg output directory found.")

if __name__ == "__main__":
   main()
