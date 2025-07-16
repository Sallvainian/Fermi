# Web Server Configuration for Teacher Dashboard

## For Development (flutter run -d web-server)

The Flutter development server doesn't support custom headers. The console warnings you see are mostly informational and don't affect functionality:

- `developer_patch.dart:96` - Normal in development, goes away in production builds
- `-ms-high-contrast` deprecation - Browser warning, not from your code
- `GSI_LOGGER` messages - Normal Google Sign-In logging
- `Tracking Prevention` - Browser privacy feature, use Incognito mode or adjust browser settings
- `Cross-Origin-Opener-Policy` - Google's OAuth popup handling, not blocking functionality

## For Production Deployment

If deploying to a server that supports headers (Apache, Nginx, Firebase Hosting), add these:

### Apache (.htaccess)
```apache
Header set Cross-Origin-Opener-Policy "same-origin-allow-popups"
Header set X-Content-Type-Options "nosniff"
Header set X-Frame-Options "SAMEORIGIN"
```

### Nginx
```nginx
add_header Cross-Origin-Opener-Policy "same-origin-allow-popups";
add_header X-Content-Type-Options "nosniff";
add_header X-Frame-Options "SAMEORIGIN";
```

### Firebase Hosting (firebase.json)
```json
{
  "hosting": {
    "headers": [{
      "source": "**",
      "headers": [{
        "key": "Cross-Origin-Opener-Policy",
        "value": "same-origin-allow-popups"
      }]
    }]
  }
}
```

## Browser Settings for Development

To reduce tracking prevention warnings during development:
1. Use Chrome instead of Edge
2. Or in Edge: Settings > Privacy > Tracking prevention > Set to "Basic" or turn off
3. Or use InPrivate/Incognito mode

## Summary

These console warnings are **normal in development** and don't indicate actual problems with your code. They come from:
- Flutter's development mode
- Browser security features
- Third-party libraries (Google Sign-In)

Your authentication is working correctly despite these warnings.