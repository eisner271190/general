---
name: EPC Clean Code
description: Principios y reglas de código limpio propias
---

## Reglas
- R1: Los métodos deben tener máximo 20 lineas. Extraer lógica a métodos auxiliares cuando sea necesario.
- R2: Extrae toda lógica contenida dentro de bloques de llaves en métodos auxiliares. Extraer cada if/for a un método.
- R3: Define una única clase o interfaz por archivo.
- R4: Cuando existan múltiples variantes de una operación, encapsula cada variante en una implementación de Strategy y ejecútalas mediante la abstracción común.
- R5: Todos los querys deben estar encapsulados en métodos
- R6: Extrae una condición cuando combine 2 o más comparaciones mediante operadores lógicos, o cuando su expresión requiera interpretación para entender su intención.
- R7: Limita los métodos a un máximo de 2 parámetros. Si un método requiere más, agrúpalos en una abstracción; esta excepción solo aplica a métodos Factory.
- R8: No instancies objetos directamente en el flujo principal; encapsula cada creación en un método dedicado y descriptivo.

## Patrón Facade
- R9: Propiciar el uso del patrón Facade para simplificar los métodos.
class PedidoFacade {
    void procesar(Pedido pedido) {
        validar(pedido);
        calcularTotal(pedido);
        guardar(pedido);
        notificar(pedido);
    }
}