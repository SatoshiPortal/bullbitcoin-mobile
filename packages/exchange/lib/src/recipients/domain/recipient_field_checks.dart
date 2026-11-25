/// Checks of single recipient fields, shared by the forms and the domain.
library;

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Whether [email] has the shape of an address: one `@`, a dot in the
/// domain, no spaces. The server checks deliverability, not the app.
bool emailLooksValid(String email) => _email.hasMatch(email.trim());
