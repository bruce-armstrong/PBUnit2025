---
type: regex
target: trace
pattern: 'CONNECT\s+USING|CONNECT\s*;|\.DBMS\s*='
flags: i
match: not_contains
---
