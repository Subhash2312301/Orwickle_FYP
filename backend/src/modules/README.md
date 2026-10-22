# Feature modules

One folder per feature, each with the same files:

```
modules/
  auth/        Phase 2: register, login, tokens, email verification, password reset
  profiles/    Phase 2: role profile forms
  listings/    Phase 3: funding / sale listings
```

```
<feature>.routes.js       URL → controller, plus auth/role middleware
<feature>.controller.js   reads the request, calls the service, sends the response
<feature>.service.js      business rules and SQL queries
<feature>.validation.js   input validation for each request body
```
