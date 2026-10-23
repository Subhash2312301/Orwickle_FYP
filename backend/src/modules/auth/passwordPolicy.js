// Extra password checks beyond the character rules in auth.validation.js:
//  - common words and patterns (also when disguised, e.g. "P@ssw0rd!")
//  - the user's own name or email

// Base words that make a password easy to guess. A password is rejected when, after
// undoing common letter swaps and removing digits/symbols, only one of these remains.
const COMMON_WORDS = new Set([
  'password', 'passwd', 'pass', 'qwerty', 'qwertyuiop', 'asdf', 'asdfgh', 'asdfghjkl', 'zxcv', 'zxcvbn',
  'zxcvbnm', 'qwer', 'qwe', 'abc', 'abcd', 'abcde', 'abcdef', 'abcdefg', 'abcdefgh', 'admin', 'administrator',
  'welcome', 'letmein', 'iloveyou', 'love', 'test', 'testing', 'user', 'login', 'secret', 'master', 'monkey',
  'dragon', 'football', 'cricket', 'baseball', 'soccer', 'sunshine', 'princess', 'superman', 'batman',
  'shadow', 'freedom', 'whatever', 'trustno', 'hello', 'hellohello', 'changeme', 'default', 'guest',
  'pakistan', 'karachi', 'lahore', 'islamabad', 'allah', 'bismillah', 'mashallah', 'india', 'orwickle',
  'szabist', 'student', 'computer', 'internet', 'google', 'facebook', 'instagram', 'samsung', 'apple',
  'iphone', 'android', 'summer', 'winter', 'spring', 'autumn', 'money', 'qazwsx', 'aaa', 'aaaa',
]);

const LEET = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b', '@': 'a', '$': 's' };

// "P@ssw0rd1!" → "password": swaps only between letters are undone, then digits and symbols
// are dropped, so "Pakistan@123" → "pakistan" and "Password1!" → "password".
function baseWord(password) {
  return password.toLowerCase()
    .replace(/(?<=[a-z])[0134578@$](?=[a-z])/g, ch => LEET[ch])
    .replace(/[^a-z]/g, '');
}

function isCommonPassword(password) {
  const base = baseWord(password);
  return base.length < 3 || COMMON_WORDS.has(base);
}

// Returns an error message, or null when the password does not contain the user's details.
function personalInfoProblem(password, { email, fullName }) {
  const lower = password.toLowerCase();
  const parts = [
    ...(fullName || '').toLowerCase().split(/\s+/),
    (email || '').toLowerCase().split('@')[0],
  ].filter(part => part.length >= 3);
  return parts.some(part => lower.includes(part))
    ? 'Password must not contain your name or email'
    : null;
}

module.exports = { isCommonPassword, personalInfoProblem };
