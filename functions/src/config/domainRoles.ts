export interface DomainRoleMapping {
  domain: string;
  role: 'teacher' | 'student' | 'admin';
  description?: string;
}

export const DOMAIN_ROLE_MAPPINGS: DomainRoleMapping[] = [
  {
    domain: '@roselleschools.org',
    role: 'teacher',
    description: 'Teacher accounts for Roselle Schools'
  },
  {
    domain: '@rosellestudent.org', 
    role: 'student',
    description: 'Student accounts for Roselle Schools'
  }
];

export const ADMIN_EMAILS = [
  'frank@admin.fermi.edu',
  'admin@fermi.edu'
];

export function getRoleFromEmail(email: string): 'teacher' | 'student' | 'admin' | null {
  const emailLower = email.toLowerCase();
  
  if (ADMIN_EMAILS.includes(emailLower)) {
    return 'admin';
  }
  
  for (const mapping of DOMAIN_ROLE_MAPPINGS) {
    if (emailLower.endsWith(mapping.domain.toLowerCase())) {
      return mapping.role;
    }
  }
  
  return null;
}

export function isValidSchoolEmail(email: string): boolean {
  const emailLower = email.toLowerCase();
  
  if (ADMIN_EMAILS.includes(emailLower)) {
    return true;
  }
  
  return DOMAIN_ROLE_MAPPINGS.some(mapping => 
    emailLower.endsWith(mapping.domain.toLowerCase())
  );
}