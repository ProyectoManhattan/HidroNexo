// Clave de operador: memoria + sessionStorage. Sin dependencias para evitar ciclos con store.ts.
const K = 'operadorClave'
let clave: string | null = null
try { clave = sessionStorage.getItem(K) } catch { /* sin storage */ }
const oyentes = new Set<() => void>()

export const getClave = () => clave
export function setClave(c: string | null) {
  clave = c
  try { c ? sessionStorage.setItem(K, c) : sessionStorage.removeItem(K) } catch { /* ignorar */ }
  oyentes.forEach((f) => f())
}
export function onClaveChange(f: () => void) {
  oyentes.add(f)
  return () => { oyentes.delete(f) }
}
