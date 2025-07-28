#!/usr/bin/env python3

import os
import xml.etree.ElementTree as ET
from datetime import datetime
import html
from collections import defaultdict

# Path to Project Inspection folder
INSPECTION_DIR = r"C:\Users\frank\Projects\teacher-dashboard-flutter-firebase\Project Inspection"
OUTPUT_FILE = r"C:\Users\frank\Projects\teacher-dashboard-flutter-firebase\project-inspection-errors.xml"

def categorize_problem_class(problem_class_id):
    """Categorize problem based on its ID."""
    if problem_class_id.startswith('AndroidLint'):
        return 'android-lint', 'medium'
    elif problem_class_id in ['Deprecation', 'GrDeprecatedAPIUsage']:
        return 'deprecation', 'medium'
    elif problem_class_id in ['unused', 'UnusedAssignment', 'UnusedReturnValue']:
        return 'unused-code', 'low'
    elif 'Error' in problem_class_id or 'Exception' in problem_class_id:
        return 'errors', 'high'
    elif problem_class_id in ['NullableProblems', 'NotNullFieldNotInitialized']:
        return 'null-safety', 'high'
    elif problem_class_id.startswith('Py'):
        return 'python', 'medium'
    elif problem_class_id in ['ShellCheck']:
        return 'shell-scripts', 'medium'
    elif problem_class_id.startswith('Html') or problem_class_id.startswith('Xml'):
        return 'markup', 'low'
    elif problem_class_id in ['FieldCanBeLocal', 'FieldMayBeFinal', 'CanBeFinal']:
        return 'code-quality', 'low'
    elif problem_class_id in ['RedundantCast', 'RedundantSuppression', 'RedundantVisibilityModifier']:
        return 'redundancy', 'low'
    else:
        return 'miscellaneous', 'low'

def parse_inspection_file(filepath):
    """Parse a single inspection XML file."""
    problems = []
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()
        
        if root.tag == 'problems':
            for problem in root.findall('problem'):
                problem_data = {
                    'file': problem.findtext('file', ''),
                    'line': problem.findtext('line', '0'),
                    'column': problem.findtext('column', '0'),
                    'module': problem.findtext('module', ''),
                    'package': problem.findtext('package', ''),
                    'language': problem.findtext('language', 'UNKNOWN'),
                    'offset': problem.findtext('offset', '0'),
                    'length': problem.findtext('length', '0'),
                    'highlighted_element': problem.findtext('highlighted_element', ''),
                    'description': problem.findtext('description', ''),
                }
                
                # Extract problem class info
                problem_class = problem.find('problem_class')
                if problem_class is not None:
                    problem_data['problem_class_id'] = problem_class.get('id', 'unknown')
                    problem_data['severity'] = problem_class.get('severity', 'WARNING')
                    problem_data['problem_class_text'] = problem_class.text or ''
                else:
                    problem_data['problem_class_id'] = 'unknown'
                    problem_data['severity'] = 'WARNING'
                    problem_data['problem_class_text'] = ''
                
                # Extract hints if present
                hints = []
                hints_elem = problem.find('hints')
                if hints_elem is not None:
                    for hint in hints_elem.findall('hint'):
                        hints.append(hint.get('value', ''))
                problem_data['hints'] = hints
                
                # Get category and priority
                category, priority = categorize_problem_class(problem_data['problem_class_id'])
                problem_data['category'] = category
                problem_data['priority'] = priority
                
                problems.append(problem_data)
                
    except Exception as e:
        print(f"Error parsing {filepath}: {e}")
    
    return problems

def main():
    """Main function to parse all inspection files and create comprehensive XML."""
    all_problems = []
    category_counts = defaultdict(int)
    severity_counts = defaultdict(int)
    priority_counts = defaultdict(int)
    file_count = 0
    
    # Parse all XML files
    for filename in os.listdir(INSPECTION_DIR):
        if filename.endswith('.xml'):
            filepath = os.path.join(INSPECTION_DIR, filename)
            problems = parse_inspection_file(filepath)
            all_problems.extend(problems)
            file_count += 1
            
            # Update counts
            for problem in problems:
                category_counts[problem['category']] += 1
                severity_counts[problem['severity']] += 1
                priority_counts[problem['priority']] += 1
    
    # Sort problems by priority, then category, then file, then line
    priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
    all_problems.sort(key=lambda p: (
        priority_order.get(p['priority'], 4),
        p['category'],
        p['file'],
        int(p['line'])
    ))
    
    # Create comprehensive XML
    root = ET.Element('project-errors', version='1.0')
    
    # Add metadata
    metadata = ET.SubElement(root, 'metadata')
    ET.SubElement(metadata, 'scan-date').text = datetime.now().isoformat()
    ET.SubElement(metadata, 'project-name').text = 'teacher-dashboard-flutter-firebase'
    ET.SubElement(metadata, 'total-errors').text = str(len(all_problems))
    ET.SubElement(metadata, 'files-analyzed').text = str(file_count)
    
    # Add severity summary
    severity_summary = ET.SubElement(metadata, 'severity-summary')
    for severity, count in severity_counts.items():
        ET.SubElement(severity_summary, severity.lower()).text = str(count)
    
    # Add category summary
    category_summary = ET.SubElement(metadata, 'category-summary')
    for category, count in sorted(category_counts.items()):
        elem = ET.SubElement(category_summary, 'category', name=category)
        elem.text = str(count)
    
    # Add errors
    errors = ET.SubElement(root, 'errors')
    for idx, problem in enumerate(all_problems):
        error_id = f"ERR-{problem['category'].upper()}-{idx:04d}"
        error = ET.SubElement(errors, 'error',
                            id=error_id,
                            category=problem['category'],
                            severity=problem['severity'],
                            priority=problem['priority'])
        
        # Clean file path
        file_path = problem['file'].replace('file://$USER_HOME$/', '~/').replace('\\', '/')
        
        ET.SubElement(error, 'file').text = file_path
        ET.SubElement(error, 'line').text = problem['line']
        ET.SubElement(error, 'column').text = problem['column']
        ET.SubElement(error, 'problem-class-id').text = problem['problem_class_id']
        ET.SubElement(error, 'problem-class-text').text = problem['problem_class_text']
        ET.SubElement(error, 'description').text = problem['description']
        ET.SubElement(error, 'highlighted-element').text = problem['highlighted_element']
        ET.SubElement(error, 'language').text = problem['language']
        ET.SubElement(error, 'module').text = problem['module']
        ET.SubElement(error, 'package').text = problem['package']
        
        if problem['hints']:
            hints_elem = ET.SubElement(error, 'hints')
            for hint in problem['hints']:
                ET.SubElement(hints_elem, 'hint').text = hint
    
    # Write to file
    tree = ET.ElementTree(root)
    ET.indent(tree, space='  ')
    tree.write(OUTPUT_FILE, encoding='utf-8', xml_declaration=True)
    
    # Print summary
    print(f"Successfully processed {file_count} inspection files")
    print(f"Total errors found: {len(all_problems)}")
    print(f"Output saved to: {OUTPUT_FILE}")
    print("\nCategory breakdown:")
    for category, count in sorted(category_counts.items()):
        print(f"  {category}: {count}")
    print("\nSeverity breakdown:")
    for severity, count in sorted(severity_counts.items()):
        print(f"  {severity}: {count}")

if __name__ == "__main__":
    main()