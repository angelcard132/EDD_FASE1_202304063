{
  ESTRUCTURA DE DATOS: PILA (LIFO - Last In, First Out)
  
  Implementa una pila para la papelera de correos eliminados.
  El último correo eliminado es el primero en mostrarse (más reciente arriba).
  
  Características:
  - LIFO: Último en entrar, primero en salir
  - Operaciones: Push (agregar al tope), Pop (quitar del tope)
  - Puntero: tope (único punto de acceso)
  - Uso: Papelera de reciclaje con correos eliminados
}
unit pila;

{$mode objfpc}{$H+}

interface

type
  // NODO DE LA PILA: Representa un correo eliminado
  PCorreoPila = ^TCorreoPila;
  TCorreoPila = record
    id: Integer;              // Identificador único del correo
    remitente: String;        // Email del usuario que envió
    asunto: String;           // Asunto del correo eliminado
    fecha: String;            // Fecha original del correo
    mensaje: String;          // Contenido del mensaje
    siguiente: PCorreoPila;   // Puntero al siguiente correo en pila
  end;

  // ESTRUCTURA DE LA PILA: Solo mantiene puntero al tope
  TPila = record
    tope: PCorreoPila;        // Único punto de acceso (tope de la pila)
  end;

// Inicializar pila vacía
procedure InicializarPila(var pila: TPila);

// Agregar correo al tope de la pila (LIFO)
procedure Push(var pila: TPila; id: Integer; remitente, asunto, fecha, mensaje: String);

// Remover y retornar el correo del tope (LIFO)
function Pop(var pila: TPila): PCorreoPila;

// Mostrar todos los correos en la pila (para debug)
procedure MostrarPila(pila: TPila);

// Buscar correo en la papelera por palabra clave
function BuscarEnPapelera(pila: TPila; clave: String): PCorreoPila;

implementation

{
  INICIALIZAR PILA
  
  Establece la pila en estado vacío.
  Complejidad: O(1)
}
procedure InicializarPila(var pila: TPila);
begin
  pila.tope := nil;  // Pila inicialmente vacía
end;

{
  PUSH
  
  Agrega un nuevo correo al tope de la pila (operación LIFO).
  El nuevo elemento se convierte en el nuevo tope.
  
  Complejidad: O(1) - inserción al inicio
}
procedure Push(var pila: TPila; id: Integer; remitente, asunto, fecha, mensaje: String);
var
  nuevo: PCorreoPila;
begin
  // Crear nuevo nodo en memoria dinámica
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.asunto := asunto;
  nuevo^.fecha := fecha;
  nuevo^.mensaje := mensaje;
  nuevo^.siguiente := pila.tope;  // El nuevo apunta al tope anterior
  pila.tope := nuevo;             // El nuevo se convierte en el tope
end;

{
  POP
  
  Remueve y retorna el correo del tope de la pila (operación LIFO).
  
  Casos:
  1. Pila vacía: Retorna nil
  2. Pila con elementos: Remueve el tope y actualiza al siguiente
  
  Complejidad: O(1) - acceso directo al tope
}
function Pop(var pila: TPila): PCorreoPila;
var
  aux: PCorreoPila;
begin
  // Caso 1: Pila vacía
  if pila.tope = nil then
    Exit(nil);

  // Guardar referencia al elemento a remover
  aux := pila.tope;
  pila.tope := pila.tope^.siguiente;  // Actualizar tope al siguiente
  Pop := aux;  // Retornar el nodo removido
end;

{
  MOSTRAR PILA
  
  Recorre e imprime todos los correos desde el tope hacia abajo.
  Muestra los correos en orden LIFO (más recientes primero).
  
  Complejidad: O(n) donde n = número de correos en pila
}
procedure MostrarPila(pila: TPila);
var
  aux: PCorreoPila;
begin
  aux := pila.tope;
  
  // Verificar si la pila está vacía
  if aux = nil then
  begin
    WriteLn('La papelera está vacía');
    Exit;
  end;

  // Recorrer desde el tope hacia abajo
  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id, ' | De: ', aux^.remitente, ' | Asunto: ', aux^.asunto, 
            ' | Fecha: ', aux^.fecha);
    aux := aux^.siguiente;  // Avanzar al siguiente en pila
  end;
end;

{
  BUSCAR EN PAPELERA
  
  Busca un correo en la papelera por palabra clave en el asunto.
  Realiza búsqueda insensible a mayúsculas/minúsculas.
  
  Complejidad: O(n) donde n = número de correos en papelera
}
function BuscarEnPapelera(pila: TPila; clave: String): PCorreoPila;
var
  aux: PCorreoPila;
begin
  BuscarEnPapelera := nil;  // Valor por defecto si no se encuentra
  aux := pila.tope;
  
  // Recorrer toda la pila buscando la clave
  while aux <> nil do
  begin
    // Búsqueda insensible a mayúsculas en el asunto
    if Pos(LowerCase(clave), LowerCase(aux^.asunto)) > 0 then
    begin
      BuscarEnPapelera := aux;  // Correo encontrado
      Exit;
    end;
    aux := aux^.siguiente;  // Continuar búsqueda
  end;
end;

end.
