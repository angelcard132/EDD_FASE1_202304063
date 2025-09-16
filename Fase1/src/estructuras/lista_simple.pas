{
  ESTRUCTURA DE DATOS: LISTA SIMPLE
  
  Implementa una lista simplemente enlazada para almacenar usuarios.
  Cada nodo apunta únicamente al siguiente, permitiendo navegación unidireccional.
  
  Características:
  - Inserción al final: O(n)
  - Búsqueda: O(n)  
  - No hay navegación hacia atrás
  - Memoria eficiente (solo un puntero por nodo)
}
unit lista_simple;

{$mode objfpc}{$H+}

interface

type
  // NODO DE LA LISTA: Representa un usuario en el sistema
  PUsuario = ^TUsuario;
  TUsuario = record
    id: Integer;         // Identificador único del usuario
    nombre: String;      // Nombre completo del usuario
    usuario: String;     // Nombre de usuario para login
    email: String;       // Correo electrónico (clave única)
    telefono: String;    // Número telefónico
    password: String;    // Contraseña para autenticación
    siguiente: PUsuario; // Puntero al siguiente usuario en la lista
  end;

  // ESTRUCTURA DE LA LISTA: Mantiene referencia al primer nodo
  TListaUsuarios = record
    primero: PUsuario;   // Puntero al primer usuario de la lista
  end;

// Inicializar lista vacía
procedure InicializarListaUsuarios(var lista: TListaUsuarios);

// Insertar nuevo usuario al final de la lista
procedure InsertarUsuario(var lista: TListaUsuarios; id: Integer; nombre, usuario, email, telefono, password: String);

// Mostrar todos los usuarios en consola (para debug)
procedure MostrarUsuarios(const lista: TListaUsuarios);

// Buscar usuario por email (función de autenticación)
function BuscarUsuarioPorEmail(const lista: TListaUsuarios; const email: String): PUsuario;

// Buscar usuario por nombre de usuario (función de autenticación alternativa)
function BuscarUsuarioPorUsuario(const lista: TListaUsuarios; const usuario: String): PUsuario;

// Obtener el siguiente ID disponible para nuevos usuarios
function ObtenerSiguienteID(const lista: TListaUsuarios): Integer;

implementation

{
  INICIALIZAR LISTA USUARIOS
  
  Establece la lista en estado vacío.
  Complejidad: O(1)
}
procedure InicializarListaUsuarios(var lista: TListaUsuarios);
begin
  lista.primero := nil;  // Lista inicialmente vacía
end;

{
  INSERTAR USUARIO
  
  Agrega un nuevo usuario al final de la lista.
  Complejidad: O(n) - debe recorrer hasta el final
}
procedure InsertarUsuario(var lista: TListaUsuarios; id: Integer; nombre, usuario, email, telefono, password: String);
var
  nuevo, aux: PUsuario;
begin
  // Crear nuevo nodo en memoria dinámica
  New(nuevo);
  nuevo^.id := id;
  nuevo^.nombre := nombre;
  nuevo^.usuario := usuario;
  nuevo^.email := email;
  nuevo^.telefono := telefono;
  nuevo^.password := password;
  nuevo^.siguiente := nil;  // Último nodo apunta a nil

  // Caso 1: Lista vacía - el nuevo nodo es el primero
  if lista.primero = nil then
    lista.primero := nuevo
  else
  begin
    // Caso 2: Lista con elementos - buscar el final
    aux := lista.primero;
    while aux^.siguiente <> nil do  // Recorrer hasta el último
      aux := aux^.siguiente;
    aux^.siguiente := nuevo;        // Enlazar al final
  end;
end;

{
  MOSTRAR USUARIOS
  
  Recorre e imprime toda la lista de usuarios.
  Complejidad: O(n)
}
procedure MostrarUsuarios(const lista: TListaUsuarios);
var
  aux: PUsuario;
begin
  aux := lista.primero;
  // Recorrer toda la lista hasta llegar a nil
  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id, ' | Nombre: ', aux^.nombre, ' | Usuario: ', aux^.usuario,
            ' | Email: ', aux^.email, ' | Tel: ', aux^.telefono);
    aux := aux^.siguiente;  // Avanzar al siguiente nodo
  end;
end;

{
  BUSCAR USUARIO POR EMAIL
  
  Busca un usuario específico por su dirección de correo.
  Complejidad: O(n) en el peor caso
}
function BuscarUsuarioPorEmail(const lista: TListaUsuarios; const email: String): PUsuario;
var
  aux: PUsuario;
begin
  aux := lista.primero;
  // Recorrer lista comparando emails (insensible a mayúsculas)
  while (aux <> nil) and (LowerCase(aux^.email) <> LowerCase(email)) do
    aux := aux^.siguiente;
  
  // Retorna el usuario encontrado o nil si no existe
  BuscarUsuarioPorEmail := aux;
end;

function BuscarUsuarioPorUsuario(const lista: TListaUsuarios; const usuario: String): PUsuario;
var
  aux: PUsuario;
begin
  aux := lista.primero;
  // Recorrer lista comparando nombres de usuario (insensible a mayúsculas)
  while (aux <> nil) and (LowerCase(aux^.usuario) <> LowerCase(usuario)) do
    aux := aux^.siguiente;

  // Retorna el usuario encontrado o nil si no existe
  BuscarUsuarioPorUsuario := aux;
end;

function ObtenerSiguienteID(const lista: TListaUsuarios): Integer;
var
  aux: PUsuario;
  maxid: Integer;
begin
  maxid := 0;
  aux := lista.primero;
  // Recorrer lista para encontrar el ID máximo
  while aux <> nil do
  begin
    if aux^.id > maxid then
      maxid := aux^.id;
    aux := aux^.siguiente;
  end;
  
  // Retornar el siguiente ID disponible
  ObtenerSiguienteID := maxid + 1;
end;

end.
