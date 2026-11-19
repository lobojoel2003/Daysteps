# Security policy

## Supported versions

Only the latest release of Daysteps receives fixes.

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Instead use
GitHub's private vulnerability reporting: open the repository's **Security**
tab and choose **Report a vulnerability**.

Useful things to include: the version (Settings → About), Android version or
browser, what you did, and what happened. You should hear back within a week.

Daysteps stores everything on the device and has no server, so the most
relevant areas are file and QR-code import (`lib/src/share/`) and the optional
ARASAAC download (`lib/src/services/arasaac.dart`).
