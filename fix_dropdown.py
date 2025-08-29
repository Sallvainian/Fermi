#!/usr/bin/env python3
import os
import re

# List of files to fix
files_to_fix = [
    'lib/features/grades/presentation/screens/teacher/grade_analytics_screen.dart',
    'lib/features/assignments/presentation/screens/teacher/assignments_list_screen.dart',
    'lib/features/assignments/presentation/screens/teacher/assignment_edit_screen.dart',
    'lib/features/assignments/presentation/screens/teacher/assignment_create_screen.dart',
    'lib/features/calendar/presentation/screens/calendar_screen.dart',
    'lib/features/classes/presentation/widgets/create_class_dialog.dart',
    'lib/features/classes/presentation/widgets/create_student_dialog.dart',
    'lib/shared/screens/contact_support_screen.dart'
]

for filepath in files_to_fix:
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Find and replace DropdownButtonFormField with initialValue
        # This regex looks for DropdownButtonFormField followed by initialValue within the same widget
        pattern = r'(DropdownButtonFormField[^{]*\{[^}]*?)initialValue:'
        new_content = re.sub(pattern, r'\1value:', content)
        
        if new_content != content:
            with open(filepath, 'w') as f:
                f.write(new_content)
            print(f"Fixed: {filepath}")
        else:
            print(f"No changes needed: {filepath}")
    else:
        print(f"File not found: {filepath}")