# Twogether App - TODO List

This document tracks pending issues, bugs, and future enhancements for the Twogether App.

## Critical Issues

- [ ] **Fix corrupted image handling in chat**: Some images with truncated base64 data fail to display (see logs for error: `Invalid character at character 99978`). Current workaround shows placeholder image but we need a more robust solution.
  - Current approach tries to pad base64 strings but fails with certain Unicode characters in the payload
  - Consider approach to either strip problematic characters or always fall back to URL for large base64 strings

## Bug Fixes

- [ ] **Chat page image loading**: Review base64 truncation logic in `ChatRepository` to prevent corrupted base64 strings
  - Truncation at 100KB appears to create invalid base64 strings
  - Consider either: 
    1. Not truncating base64 data
    2. Only including base64 data for small images (<50KB)
    3. Using a better truncation algorithm that preserves valid base64 structure
- [ ] **Platform detection in admin chat page**: Fix the action button UI to correctly show bottom sheet on mobile and popup menu on desktop
  - Current implementation still shows web popup in mobile view
  - Review the platform detection logic in `_buildActionsButton` method
  - Ensure proper UI handling based on screen size and platform
- [ ] **Service submission document rendering**: Fix document display in service submissions
  - The `documentUrls` field is not being populated with uploaded invoice URLs
  - Improve the image URL handling between Firebase Storage and Firestore
  - Consider updating the service submission repository to properly set document URLs upon upload
  - Add consistent error handling for image loading failures
- [x] **Real-time notifications in reseller home page**: Implement functional notifications for service submissions status changes
  - Created notification data model and repository
  - Added UI integration to display real-time notifications in the home page
  - Implemented notification badges and status change tracking
  - Added ability to navigate to relevant screens when tapping notifications
  - Notifications are now marked as read when viewed

## UI Improvements

- [ ] **Chat input field responsiveness**: Ensure input field adjusts properly on different screen sizes
- [ ] **Dark mode theme adjustments**: Review color contrasts in dark mode for better readability
- [ ] **Loading indicators**: Add better loading states throughout the app

## Feature Enhancements

- [ ] **Send images with text captions**: Implement the capability to send images with accompanying text in the same message
  - Update `ChatMessage` model to include an optional text caption field for image messages
  - Modify the message type enum to include a new `imageWithText` type
  - Update the repository to handle the new message type
  - Enhance the image preview screen to include a text input field
  - Update the message bubble rendering to display both image and text
- [ ] **Improve offline image support**: Enhance caching for better offline experience
- [ ] **Message search functionality**: Add ability to search messages within conversations
- [ ] **Group conversations**: Support for multi-user conversations
- [x] **Notification system implementation**: Real-time notification system for service status changes
  - Created notification data model and repository for Firestore integration
  - Implemented UI components to display notifications in the reseller home page
  - Added notification badges and status change tracking
  - Created Cloud Function to generate notifications on submission status updates
  - Implemented notification actions (mark as read, navigate to related content)
- [ ] **Complete push notification integration**: Finalize the push notification system for the reseller home page
  - Add Firebase Cloud Messaging (FCM) dependencies to pubspec.yaml
  - Configure platform-specific files (AndroidManifest.xml, Info.plist)
  - Create a notification service to handle FCM tokens and messages
  - Store FCM tokens in Firestore when users log in
  - Update the Cloud Function to send push notifications through FCM
  - Add notification permission handling for iOS devices
  - Implement foreground notification handling
  - Add deep linking support for notification taps
  - Test notification delivery across different device states (foreground, background, terminated)

## Performance Improvements

- [ ] **Image optimization**: Optimize image upload process and implement proper resizing
- [ ] **Firebase query optimization**: Review and optimize Firebase queries for better performance
- [ ] **Memory management**: Profile and optimize memory usage, especially with images

## Code Refactoring

- [ ] **Chat module architecture**: Refactor to improve separation of concerns
- [ ] **Error handling standardization**: Implement consistent error handling across the app
- [ ] **Test coverage**: Increase unit and widget test coverage

## Security

- [ ] **Sensitive data handling**: Review how sensitive user data is stored and processed
- [ ] **Firebase security rules**: Audit and enhance security rules
- [ ] **Role-based routing**: Enhance role-based routing to ensure admins cannot access reseller pages and vice versa, possibly by implementing additional server-side validation

## Accessibility

- [ ] **Screen reader support**: Improve accessibility for screen readers
- [ ] **Color contrast**: Ensure sufficient contrast for all UI elements
- [ ] **Keyboard navigation**: Enhance keyboard navigation throughout the app

## Documentation

- [ ] **Code documentation**: Improve documentation of complex components
- [ ] **User guide**: Create comprehensive user documentation 