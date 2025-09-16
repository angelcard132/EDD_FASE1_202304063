{
  ESTRUCTURA DE DATOS: LISTA CIRCULAR
  
  Implementa una lista doblemente enlazada circular para contactos personales.
  Cada nodo tiene enlaces anterior y siguiente, y el último nodo apunta al primero.
  
  Características:
  - Navegación infinita: Se puede recorrer indefinidamente
  - Acceso bidireccional: Hacia adelante y hacia atrás
  - Sin fin: El último elemento apunta al primero
  - Optimizada para listas pequeñas de contactos personales
}
unit lista_circular;

{$mode objfpc}{$H+}

interface

type
  // NODO DE LA LISTA: Representa un contacto personal
  PContacto = ^TContacto;
  TContacto = record
    id: Integer;            // Identificador único del contacto
    nombre: String;         // Nombre completo del contacto
    nombreUsuario: String;  // Nombre de usuario del contacto
    email: String;          // Dirección de correo electrónico
    siguiente: PContacto;   // Puntero al siguiente contacto (circular)
    anterior: PContacto;    // Puntero al contacto anterior (circular)
  end;

  // ESTRUCTURA DE LA LISTA: Solo mantiene referencia al primer nodo
  TListaContactos = record
    primero: PContacto;     // Primer contacto (punto de entrada)
  end;

// Inicializar lista circular vacía
procedure InicializarContactos(var lista: TListaContactos);

// Insertar nuevo contacto manteniendo la circularidad
procedure InsertarContacto(var lista: TListaContactos; id: Integer; nombre, nombreUsuario, email: String);

// Mostrar contactos con límite para evitar bucles infinitos
procedure MostrarContactos(lista: TListaContactos; limite: Integer);

// Buscar contacto por email en la lista circular
function BuscarContacto(lista: TListaContactos; email: String): PContacto;

// Buscar contacto por nombre de usuario en la lista circular
function BuscarContactoPorUsuario(lista: TListaContactos; nombreUsuario: String): PContacto;

implementation

{
  INICIALIZAR CONTACTOS
  
  Establece la lista circular en estado vacío.
  Complejidad: O(1)
}
procedure InicializarContactos(var lista: TListaContactos);
begin
  lista.primero := nil;  // Lista circular vacía
end;

{
  INSERTAR CONTACTO
  
  Agrega un nuevo contacto manteniendo la estructura circular.
  
  Casos:
  1. Lista vacía: El nodo apunta a sí mismo
  2. Lista con elementos: Se inserta al final y se mantiene la circularidad
  
  Complejidad: O(1) - acceso directo al último elemento
}
procedure InsertarContacto(var lista: TListaContactos; id: Integer; nombre, nombreUsuario, email: String);
var
  nuevo, ultimo: PContacto;
begin
  // Crear nuevo nodo en memoria dinámica
  New(nuevo);
  nuevo^.id := id;
  nuevo^.nombre := nombre;
  nuevo^.nombreUsuario := nombreUsuario;
  nuevo^.email := email;

  // Caso 1: Lista vacía - el nodo apunta a sí mismo
  if lista.primero = nil then
  begin
    lista.primero := nuevo;
    nuevo^.siguiente := nuevo;    // Apunta a sí mismo
    nuevo^.anterior := nuevo;     // Apunta a sí mismo
  end
  else
  begin
    // Caso 2: Lista con elementos - insertar al final
    ultimo := lista.primero^.anterior;  // El último es el anterior al primero
    
    // Actualizar enlaces para mantener circularidad
    ultimo^.siguiente := nuevo;         // El último apunta al nuevo
    nuevo^.anterior := ultimo;          // El nuevo tiene como anterior al último
    nuevo^.siguiente := lista.primero;  // El nuevo apunta al primero
    lista.primero^.anterior := nuevo;   // El primero tiene como anterior al nuevo
  end;
end;

{
  MOSTRAR CONTACTOS
  
  Recorre la lista circular mostrando contactos hasta el límite especificado.
  El límite previene bucles infinitos en la naturaleza circular.
  
  Complejidad: O(n) limitado por el parámetro 'limite'
}
procedure MostrarContactos(lista: TListaContactos; limite: Integer);
var
  aux: PContacto;
  count: Integer;
begin
  // Verificar si la lista está vacía
  if lista.primero = nil then
  begin
    WriteLn('No hay contactos');
    Exit;
  end;

  aux := lista.primero;
  count := 0;
  
  // Recorrer lista circular hasta el límite o completar una vuelta
  repeat
    Inc(count);
    WriteLn('ID: ', aux^.id, ' | Nombre: ', aux^.nombre, ' | Email: ', aux^.email);
    aux := aux^.siguiente;  // Avanzar al siguiente (circular)
  until (aux = lista.primero) or (count = limite);  // Parar si volvemos al inicio o alcanzamos límite
end;

{
  BUSCAR CONTACTO
  
  Busca un contacto por email en la lista circular.
  Recorre la lista una sola vez para evitar bucles infinitos.
  
  Complejidad: O(n) donde n = número de contactos
}
function BuscarContacto(lista: TListaContactos; email: String): PContacto;
var
  aux: PContacto;
begin
  BuscarContacto := nil;  // Valor por defecto si no se encuentra
  
  // Verificar si la lista está vacía
  if lista.primero = nil then Exit;

  aux := lista.primero;
  
  // Recorrer lista circular una sola vez
  repeat
    // Comparar email (búsqueda exacta)
    if aux^.email = email then
    begin
      BuscarContacto := aux;  // Contacto encontrado
      Exit;
    end;
    aux := aux^.siguiente;  // Avanzar al siguiente nodo
  until aux = lista.primero;  // Parar cuando volvemos al inicio
end;

{
  BUSCAR CONTACTO POR USUARIO
  
  Busca un contacto por nombre de usuario en la lista circular.
  Recorre la lista una sola vez para evitar bucles infinitos.
  
  Complejidad: O(n) donde n = número de contactos
}
function BuscarContactoPorUsuario(lista: TListaContactos; nombreUsuario: String): PContacto;
var
  aux: PContacto;
begin
  BuscarContactoPorUsuario := nil;  // Valor por defecto si no se encuentra
  
  // Verificar si la lista está vacía
  if lista.primero = nil then Exit;

  aux := lista.primero;
  
  // Recorrer lista circular una sola vez
  repeat
    // Comparar nombre de usuario (búsqueda exacta)
    if aux^.nombreUsuario = nombreUsuario then
    begin
      BuscarContactoPorUsuario := aux;  // Contacto encontrado
      Exit;
    end;
    aux := aux^.siguiente;  // Avanzar al siguiente nodo
  until aux = lista.primero;  // Parar cuando volvemos al inicio
end;

end.
