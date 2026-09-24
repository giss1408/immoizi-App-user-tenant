# Immoizi User Tenant App

Flutter mobile frontend for real-estate seekers and tenants.

## Features

- Public property browsing through `publicDescriptions`
- Tenant dashboard through `myTenantProperties`
- Tenant payments, tenant-visible documents, and maintenance requests
- French-first mobile interface
- Configurable GraphQL endpoint and bearer token from the app screen

## Run

```bash
flutter pub get
flutter run
```

Default endpoint:

```text
http://127.0.0.1:8000/graphql
```

For Android emulator, use:

```text
http://10.0.2.2:8000/graphql
```

The backend must provide an authenticated bearer token compatible with the Django GraphQL auth strategy.
