# Règle : Commandes PowerShell sur Windows

Sur Windows (shell PowerShell), les commandes Unix classiques n'existent pas.
Utiliser leurs équivalents PowerShell systématiquement.

## Équivalents de commandes

| Unix | PowerShell |
|------|-----------|
| `cmd | head -n N` | `cmd | Select-Object -First N` |
| `cmd | tail -n N` | `cmd | Select-Object -Last N` |
| `grep "pattern" file` | `Select-String "pattern" file` |
| `cmd | grep "pattern"` | `cmd | Select-String "pattern"` |
| `cat file` | `Get-Content file` |
| `wc -l file` | `(Get-Content file).Count` |

> Ces équivalents s'appliquent à tous les projets sur cette machine.
