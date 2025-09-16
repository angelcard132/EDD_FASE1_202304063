{
  ESTRUCTURA DE DATOS: COLA (FIFO - First In, First Out)
  
  Implementa una cola para correos programados para envío futuro.
  El primer correo agregado es el primero en ser enviado.
  
  Características:
  - FIFO: Primer en entrar, primer en salir
  - Operaciones: Encolar (agregar al final), Desencolar (quitar del frente)
  - Punteros: frente (para sacar) y final (para agregar)
  - Uso: Programación de correos con fechas futuras
}
unit cola;

{$mode objfpc}{$H+}

interface

type
  // NODO DE LA COLA: Representa un correo programado
  PCorreoCola = ^TCorreoCola;
  TCorreoCola = record
    id: Integer;              // Identificador único del correo
    remitente: String;        // Email del usuario que envía
    destinatario: String;     // Email del usuario que recibe
    asunto: String;           // Asunto del correo
    fecha: String;            // Fecha programada para envío
    mensaje: String;          // Contenido del mensaje
    siguiente: PCorreoCola;   // Puntero al siguiente correo en cola
  end;

  // ESTRUCTURA DE LA COLA: Mantiene punteros al frente y final
  TCola = record
    frente, final: PCorreoCola;  // Frente: para desencolar, Final: para encolar
  end;

// Inicializar cola vacía
procedure InicializarCola(var cola: TCola);

// Agregar correo al final de la cola (FIFO)
procedure Encolar(var cola: TCola; id: Integer; remitente, destinatario, asunto, fecha, mensaje: String);

// Remover y retornar el primer correo de la cola (FIFO)
function Desencolar(var cola: TCola): PCorreoCola;

// Mostrar todos los correos en la cola (para debug)
procedure MostrarCola(cola: TCola);

implementation

{
  INICIALIZAR COLA
  
  Establece la cola en estado vacío.
  Complejidad: O(1)
}
procedure InicializarCola(var cola: TCola);
begin
  cola.frente := nil;  // No hay elementos al frente
  cola.final := nil;   // No hay elementos al final
end;

{
  ENCOLAR
  
  Agrega un nuevo correo al final de la cola (operación FIFO).
  
  Casos:
  1. Cola vacía: El nuevo elemento es tanto frente como final
  2. Cola con elementos: Se agrega al final y se actualiza el puntero final
  
  Complejidad: O(1) - acceso directo al final
}
procedure Encolar(var cola: TCola; id: Integer; remitente, destinatario, asunto, fecha, mensaje: String);
var
  nuevo: PCorreoCola;
begin
  // Crear nuevo nodo en memoria dinámica
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;
  nuevo^.asunto := asunto;
  nuevo^.fecha := fecha;
  nuevo^.mensaje := mensaje;
  nuevo^.siguiente := nil;  // El nuevo elemento no tiene siguiente

  // Caso 1: Cola vacía
  if cola.frente = nil then
    cola.frente := nuevo    // El nuevo elemento es el frente
  else
    cola.final^.siguiente := nuevo;  // Enlazar el anterior final con el nuevo

  cola.final := nuevo;      // Actualizar el puntero al final
end;

{
  DESENCOLAR
  
  Remueve y retorna el primer correo de la cola (operación FIFO).
  
  Casos:
  1. Cola vacía: Retorna nil
  2. Un elemento: Cola queda vacía (frente y final = nil)
  3. Múltiples elementos: Se actualiza el frente al siguiente
  
  Complejidad: O(1) - acceso directo al frente
}
function Desencolar(var cola: TCola): PCorreoCola;
var
  aux: PCorreoCola;
begin
  // Caso 1: Cola vacía
  if cola.frente = nil then
    Exit(nil);

  // Guardar referencia al elemento a remover
  aux := cola.frente;
  cola.frente := cola.frente^.siguiente;  // Avanzar el frente

  // Caso 2: Era el último elemento - cola queda vacía
  if cola.frente = nil then
    cola.final := nil;

  Desencolar := aux;  // Retornar el nodo desencolado
end;

{
  MOSTRAR COLA
  
  Recorre e imprime todos los correos en la cola desde el frente al final.
  Útil para debug y verificación del orden FIFO.
  
  Complejidad: O(n) donde n = número de correos en cola
}
procedure MostrarCola(cola: TCola);
var
  aux: PCorreoCola;
begin
  aux := cola.frente;
  
  // Verificar si la cola está vacía
  if aux = nil then
  begin
    WriteLn('La cola de correos programados está vacía');
    Exit;
  end;

  // Recorrer desde el frente hasta el final
  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id, ' | De: ', aux^.remitente, ' | Para: ', aux^.destinatario, 
            ' | Asunto: ', aux^.asunto, ' | Fecha: ', aux^.fecha);
    aux := aux^.siguiente;  // Avanzar al siguiente en cola
  end;
end;

end.
