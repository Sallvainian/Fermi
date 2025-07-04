# Prompt for Claude to Implement Teacher Dashboard Improvements

## Project Context

You are working on a Flutter/Firebase application called "Teacher Dashboard" that helps teachers manage their classrooms, students, assignments, and grades. The project is currently in a pre-MVP stage (~40% feature complete) and has been migrated from SvelteKit + Supabase to Flutter + Firebase.

The application includes:
- Authentication system (email/password, Google Sign-In)
- Role-based routing and navigation
- Basic dashboard structure for teachers/students
- Firestore security rules
- Theme system with Material 3 design
- State management with Provider pattern

Several features are in progress or not yet implemented, including assignment management, grade tracking, class management, messaging, calendar functionality, notifications, and offline support.

## Your Task

Your task is to implement improvements to the codebase based on a comprehensive checklist of tasks. You should use the Zen MCP tool to analyze the code, make changes, and test your implementations.

## Priority Areas

Focus on these high-priority improvements first:

1. **Architecture and Structure**
   - Create a centralized Firestore service
   - Implement proper dependency injection
   - Improve error handling

2. **Code Quality**
   - Fix linting issues (especially removing print statements)
   - Remove hardcoded values (particularly the Google client ID in auth_service.dart)

3. **Security Enhancements**
   - Enhance Firestore security rules
   - Improve authentication security

4. **Performance Optimization**
   - Implement proper Firestore caching for offline support
   - Optimize Firebase usage

## Complete Task List

Below is the full list of improvement tasks organized by category. For each task you implement, mark it as completed in the docs/tasks.md file by changing `[ ]` to `[x]`.

### Architecture and Structure

1. Create a centralized Firestore service
   - Implement a common FirestoreService class to handle basic CRUD operations
   - Move duplicate Firestore logic from individual services to the central service
   - Add proper error handling and logging

2. Implement proper dependency injection
   - Use a dependency injection framework like get_it or provider
   - Remove direct instantiation of services in providers
   - Make testing easier with mockable dependencies

3. Refactor provider architecture
   - Separate UI state from business logic
   - Implement repository pattern between providers and services
   - Consider using more granular providers for specific features

4. Improve error handling
   - Create a centralized error handling system
   - Implement proper error reporting to Crashlytics
   - Add user-friendly error messages and recovery options

5. Implement proper logging
   - Replace print statements with structured logging
   - Add different log levels (debug, info, warning, error)
   - Configure logging to work with Firebase Analytics

### Code Quality

6. Fix linting issues
   - Run flutter analyze and address all warnings
   - Remove all print statements from production code
   - Fix unused variables and methods

7. Enhance code documentation
   - Add proper dartdoc comments to all public APIs
   - Document complex business logic
   - Add README files to major directories explaining their purpose

8. Refactor large files
   - Break down main.dart into smaller components
   - Split large provider classes into smaller, focused providers
   - Extract reusable widgets from screen files

9. Standardize naming conventions
   - Ensure consistent naming across the codebase
   - Follow Flutter/Dart naming conventions
   - Rename ambiguous variables and methods

10. Remove hardcoded values
    - Move hardcoded strings to constants
    - Extract hardcoded dimensions to a theme file
    - Remove hardcoded Google client ID from auth_service.dart

### Performance Optimization

11. Implement proper Firestore caching
    - Configure persistence for offline support
    - Optimize query caching strategies
    - Implement data prefetching for critical screens

12. Optimize Firebase usage
    - Reduce unnecessary real-time listeners
    - Implement pagination for large collections
    - Use server timestamps consistently

13. Improve UI performance
    - Use const constructors where possible
    - Implement list view optimizations (ListView.builder)
    - Add proper loading states and skeleton screens

14. Optimize asset loading
    - Compress and optimize images
    - Implement proper asset caching
    - Use SVGs for icons where possible

15. Reduce app size
    - Configure proper code splitting
    - Remove unused dependencies
    - Optimize native builds

### Security Enhancements

16. Enhance Firestore security rules
    - Add data validation in security rules
    - Restrict class creation to teachers only
    - Implement more granular access controls

17. Improve authentication security
    - Implement email verification requirement
    - Add multi-factor authentication option
    - Enforce password complexity requirements

18. Secure sensitive data
    - Review and secure PII (Personally Identifiable Information)
    - Implement proper data encryption for sensitive fields
    - Add privacy controls for user data

19. Add API security
    - Secure Firebase Functions endpoints
    - Implement proper token validation
    - Add rate limiting for authentication attempts

20. Conduct security audit
    - Review all Firebase security rules
    - Check for common security vulnerabilities
    - Implement security best practices

### Testing

21. Implement comprehensive unit tests
    - Add tests for all service classes
    - Test providers and business logic
    - Aim for >80% code coverage

22. Add widget tests
    - Test all reusable widgets
    - Verify screen rendering and interactions
    - Test form validation and error states

23. Implement integration tests
    - Test critical user flows end-to-end
    - Verify Firebase integration
    - Test offline functionality

24. Set up CI/CD pipeline
    - Configure GitHub Actions or similar CI/CD tool
    - Automate testing on pull requests
    - Set up automated deployment

25. Add performance testing
    - Measure and track app startup time
    - Test performance on low-end devices
    - Monitor Firebase query performance

### Feature Completion

26. Complete assignment management system
    - Finish assignment creation workflow
    - Implement assignment submission
    - Add grading functionality

27. Implement grade tracking
    - Complete gradebook UI
    - Add grade analytics and reporting
    - Implement grade export functionality

28. Finish class management
    - Complete class creation and editing
    - Implement student enrollment
    - Add class analytics

29. Implement messaging system
    - Complete chat functionality
    - Add file sharing in messages
    - Implement notifications for new messages

30. Add offline support
    - Implement proper data synchronization
    - Add offline indicators
    - Handle conflict resolution

### User Experience

31. Improve accessibility
    - Add proper semantic labels
    - Ensure sufficient color contrast
    - Support screen readers

32. Enhance responsive design
    - Optimize layouts for different screen sizes
    - Improve tablet and desktop experiences
    - Fix layout issues on small screens

33. Add user onboarding
    - Create first-time user tutorials
    - Add feature discovery
    - Implement contextual help

34. Improve form validation
    - Add real-time validation feedback
    - Implement more user-friendly error messages
    - Add auto-completion where appropriate

35. Enhance visual design
    - Refine color scheme and typography
    - Add animations and transitions
    - Improve overall visual consistency

### Documentation

36. Update project documentation
    - Revise and expand README.md
    - Document architecture decisions
    - Add contribution guidelines

37. Create developer documentation
    - Document codebase structure
    - Add setup instructions for new developers
    - Document testing strategy

38. Add user documentation
    - Create user manual
    - Add FAQ section
    - Provide troubleshooting guides

39. Document Firebase configuration
    - Detail security rules and their purpose
    - Document database schema
    - Add deployment instructions

40. Create API documentation
    - Document Firebase Functions APIs
    - Add Swagger/OpenAPI documentation
    - Document authentication requirements

## Implementation Approach

For each task you implement:

1. **Analyze the current code** to understand its structure and identify areas for improvement
2. **Plan your changes** by outlining the specific files and code sections that need modification
3. **Implement the changes** using the Zen MCP tool
4. **Test your implementation** to ensure it works as expected
5. **Document your changes** by updating the relevant documentation files
6. **Mark the task as completed** in the docs/tasks.md file

## Using the Zen MCP Tool

The Zen MCP tool provides you with capabilities to analyze and modify code. Use the following approach:

1. **Code Analysis**: Use the tool to analyze the codebase and identify areas that need improvement
2. **File Navigation**: Navigate through the project files to understand the structure
3. **Code Modification**: Make changes to implement the improvements
4. **Testing**: Test your changes to ensure they work as expected
5. **Documentation**: Update documentation to reflect your changes

## Deliverables

For each task you complete, provide:

1. A summary of the changes you made
2. The files you modified
3. An explanation of how your changes improve the codebase
4. Any potential issues or limitations with your implementation
5. Suggestions for further improvements

## Final Notes

- Focus on making incremental improvements that can be easily tested and verified
- Prioritize changes that improve the architecture, security, and performance of the application
- Ensure backward compatibility with existing features
- Follow Flutter and Dart best practices
- Document your changes thoroughly