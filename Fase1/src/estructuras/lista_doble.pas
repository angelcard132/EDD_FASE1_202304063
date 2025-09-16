{
  ESTRUCTURA DE DATOS: LISTA DOBLE (SIMPLIFICADA)
  
  Implementa una lista doblemente enlazada para correos electrónicos.
  NOTA: Esta implementación solo maneja el enlace hacia adelante para simplificar.
  En una implementación completa tendría punteros anterior y siguiente.
  
  Características:
  - Inserción al final: O(1) con puntero a último
  - Navegación: Solo hacia adelante en esta implementación
  - Mantiene referencia al primer y último nodo
}
unit lista_doble;

{$mode objfpc}{$H+}

interface

type
  // NODO DE LA LISTA: Representa un correo electrónico
  PCorreo = ^TCorreo;
  TCorreo = record
    id: Integer;          // Identificador único del correo
    remitente: String;    // Email del usuario que envía
    destinatario: String; // Email del usuario que recibe
    estado: String;       // Estado: 'L'=Leído, 'NL'=No Leído, 'DEL'=Eliminado
    asunto: String;       // Asunto del correo
    fecha: String;        // Fecha de envío
    contenido: String;    // Cuerpo del mensaje
    siguiente: PCorreo;   // Puntero al siguiente correo
  end;

  // ESTRUCTURA DE LA LISTA: Mantiene referencias al primer y último nodo
  TListaCorreos = record
    primero: PCorreo;     // Puntero al primer correo
    ultimo: PCorreo;      // Puntero al último correo (optimización)
  end;

// Inicializar lista vacía
procedure InicializarListaCorreos(var lista: TListaCorreos);

// Insertar nuevo correo al final de la lista
procedure InsertarCorreo(var lista: TListaCorreos; id: Integer; remitente, destinatario, estado, asunto, fecha, contenido: String);

// Mostrar todos los correos en consola (para debug)
procedure MostrarCorreos(const lista: TListaCorreos);

implementation

{
  INICIALIZAR LISTA CORREOS
  
  Establece la lista en estado vacío.
  Complejidad: O(1)
}
procedure InicializarListaCorreos(var lista: TListaCorreos);
begin
  lista.primero := nil;  // No hay primer elemento
  lista.ultimo := nil;   // No hay último elemento
end;

{
  INSERTAR CORREO
  
  Agrega un nuevo correo al final de la lista.
  Optimización: Usa puntero 'ultimo' para inserción O(1)
}
procedure InsertarCorreo(var lista: TListaCorreos; id: Integer; remitente, destinatario, estado, asunto, fecha, contenido: String);
var
  nuevo: PCorreo;
begin
  // Crear nuevo nodo en memoria dinámica
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;
  nuevo^.estado := estado;
  nuevo^.asunto := asunto;
  nuevo^.fecha := fecha;
  nuevo^.contenido := contenido;
  nuevo^.siguiente := nil;  // Último nodo apunta a nil

  // Caso 1: Lista vacía
  if lista.primero = nil then
  begin
    lista.primero := nuevo;  // Primer y último son el mismo
    lista.ultimo := nuevo;
  end
  else
  begin
    // Caso 2: Lista con elementos - agregar al final
    lista.ultimo^.siguiente := nuevo;  // Enlazar desde el anterior último
    lista.ultimo := nuevo;             // Actualizar puntero último
  end;
end;

{
  MOSTRAR CORREOS
  
  Recorre e imprime toda la lista de correos.
  Complejidad: O(n)
}
procedure MostrarCorreos(const lista: TListaCorreos);
var
  aux: PCorreo;
begin
  aux := lista.primero;
  // Recorrer toda la lista hasta llegar a nil
  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id, ' | De: ', aux^.remitente, ' | Para: ', aux^.destinatario,
            ' | Asunto: ', aux^.asunto, ' | Estado: ', aux^.estado);
    aux := aux^.siguiente;  // Avanzar al siguiente nodo
  end;
end;

end.
