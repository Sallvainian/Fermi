import os
import re

def replace_with_values(directory):
    """Replace all withValues(alpha: x) with withOpacity(x) in Dart files."""
    
    # Pattern to match withValues(alpha: number)
    pattern = re.compile(r'withValues\(alpha:\s*([\d.]+)\)')
    
    files_modified = 0
    total_replacements = 0
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Find all matches
                    matches = pattern.findall(content)
                    if matches:
                        # Replace all occurrences
                        new_content = pattern.sub(r'withOpacity(\1)', content)
                        
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                        
                        replacements = len(matches)
                        print(f"Modified {filepath}: {replacements} replacements")
                        files_modified += 1
                        total_replacements += replacements
                        
                except Exception as e:
                    print(f"Error processing {filepath}: {e}")
    
    print(f"\nSummary: Modified {files_modified} files with {total_replacements} total replacements")

if __name__ == "__main__":
    replace_with_values("lib")
    print("Replacement complete!")