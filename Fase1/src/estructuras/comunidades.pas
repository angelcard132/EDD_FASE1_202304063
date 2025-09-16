{
  ESTRUCTURA DE DATOS: LISTA DE LISTAS (COMUNIDADES)
  
  Implementa una estructura compleja donde cada nodo de la lista principal
  contiene una sublista de miembros. Esta es la estructura más compleja del sistema.
  
  Estructura:
  - Lista Principal: Comunidades enlazadas simplemente
  - Sublistas: Cada comunidad tiene una lista simple de miembros
  - Cada miembro es una referencia a un usuario de la lista global
  
  Características:
  - Inserción de comunidad: O(n) - busca duplicados y posición final
  - Búsqueda de comunidad: O(n) en lista principal
  - Inserción de miembro: O(m) donde m = miembros de la comunidad
  - Búsqueda de miembro: O(m) dentro de cada comunidad
}
unit comunidades;

{$mode objfpc}{$H+}

interface

uses
  lista_simple,    // Para usar el tipo TUsuario
  SysUtils;        // Para funciones del sistema

type
  // PUNTERO A NODO DE COMUNIDAD
  PComunidad = ^TComunidad;
  
  // NODO DE MIEMBRO: Elemento de la sublista
  PMiembroComunidad = ^TMiembroComunidad;
  TMiembroComunidad = record
    usuario: PUsuario;                    // Referencia al usuario global (no copia)
    siguiente: PMiembroComunidad;         // Puntero al siguiente miembro
  end;
  
  // SUBLISTA: Lista simple de miembros de una comunidad
  TListaMiembros = record
    primero: PMiembroComunidad;           // Primer miembro de la comunidad
  end;
  
  // NODO PRINCIPAL: Representa una comunidad completa
  TComunidad = record
    id: Integer;                          // Identificador único de la comunidad
    nombre: String;                       // Nombre de la comunidad
    miembros: TListaMiembros;            // Sublista de miembros
    siguiente: PComunidad;                // Puntero a la siguiente comunidad
  end;
  
  // LISTA PRINCIPAL: Contiene todas las comunidades del sistema
  TListaComunidades = record
    primero: PComunidad;                  // Primera comunidad en la lista
  end;

// === FUNCIONES DE INICIALIZACIÓN ===
procedure InicializarListaComunidades(var lista: TListaComunidades);
procedure InicializarListaMiembros(var lista: TListaMiembros);

// === FUNCIONES DE GESTIÓN DE COMUNIDADES ===
function CrearComunidad(var lista: TListaComunidades; const nombre: String): Boolean;
function AgregarUsuarioAComunidad(var lista: TListaComunidades; const nombreComunidad: String; usuario: PUsuario): Boolean;

// === FUNCIONES DE BÚSQUEDA ===
function BuscarComunidadPorNombre(const lista: TListaComunidades; const nombre: String): PComunidad;
function BuscarUsuarioEnComunidad(const comunidad: PComunidad; usuario: PUsuario): Boolean;

// === FUNCIONES AUXILIARES ===
function ObtenerSiguienteIDComunidad(const lista: TListaComunidades): Integer;
function ContarMiembrosComunidad(const comunidad: PComunidad): Integer;

// === FUNCIONES DE VISUALIZACIÓN ===
procedure MostrarComunidades(const lista: TListaComunidades);
procedure MostrarMiembrosComunidad(const comunidad: PComunidad);

// === FUNCIÓN DE LIMPIEZA ===
procedure LiberarMemoriaComunidades(var lista: TListaComunidades);

implementation

{
  INICIALIZAR LISTA COMUNIDADES
  
  Establece la lista principal en estado vacío.
  Complejidad: O(1)
}
procedure InicializarListaComunidades(var lista: TListaComunidades);
begin
  lista.primero := nil;  // Lista principal vacía
end;

{
  INICIALIZAR LISTA MIEMBROS
  
  Establece una sublista de miembros en estado vacío.
  Complejidad: O(1)
}
procedure InicializarListaMiembros(var lista: TListaMiembros);
begin
  lista.primero := nil;  // Sublista vacía
end;

{
  OBTENER SIGUIENTE ID COMUNIDAD
  
  Busca el ID más alto en toda la lista principal y retorna el siguiente.
  Garantiza IDs únicos para nuevas comunidades.
  Complejidad: O(n) donde n = número de comunidades
}
function ObtenerSiguienteIDComunidad(const lista: TListaComunidades): Integer;
var
  aux: PComunidad;
  maxid: Integer;
begin
  maxid := 0;
  aux := lista.primero;
  
  // Recorrer toda la lista principal buscando el ID máximo
  while aux <> nil do
  begin
    if aux^.id > maxid then 
      maxid := aux^.id;
    aux := aux^.siguiente;
  end;
  
  ObtenerSiguienteIDComunidad := maxid + 1;
end;

{
  CREAR COMUNIDAD
  
  Crea una nueva comunidad y la agrega al final de la lista principal.
  Valida que no exista una comunidad con el mismo nombre.
  Complejidad: O(n) para buscar duplicados + O(n) para insertar al final
}
function CrearComunidad(var lista: TListaComunidades; const nombre: String): Boolean;
var
  nueva, aux: PComunidad;
begin
  // Verificar que no exista una comunidad con el mismo nombre
  if BuscarComunidadPorNombre(lista, nombre) <> nil then
  begin
    WriteLn('Error: Ya existe una comunidad con el nombre "', nombre, '"');
    CrearComunidad := False;
    Exit;
  end;
  
  // Crear nuevo nodo de comunidad en memoria dinámica
  New(nueva);
  nueva^.id := ObtenerSiguienteIDComunidad(lista);
  nueva^.nombre := nombre;
  InicializarListaMiembros(nueva^.miembros);  // Sublista inicialmente vacía
  nueva^.siguiente := nil;
  
  // Insertar al final de la lista principal
  if lista.primero = nil then
    lista.primero := nueva  // Primera comunidad
  else
  begin
    // Buscar el final de la lista principal
    aux := lista.primero;
    while aux^.siguiente <> nil do
      aux := aux^.siguiente;
    aux^.siguiente := nueva;  // Enlazar al final
  end;
  
  WriteLn('Comunidad "', nombre, '" creada exitosamente con ID: ', nueva^.id);
  CrearComunidad := True;
end;

{
  BUSCAR COMUNIDAD POR NOMBRE
  
  Busca una comunidad específica en la lista principal por su nombre.
  Búsqueda insensible a mayúsculas/minúsculas.
  Complejidad: O(n) donde n = número de comunidades
}
function BuscarComunidadPorNombre(const lista: TListaComunidades; const nombre: String): PComunidad;
var
  aux: PComunidad;
begin
  aux := lista.primero;
  
  // Recorrer lista principal comparando nombres
  while (aux <> nil) and (LowerCase(aux^.nombre) <> LowerCase(nombre)) do
    aux := aux^.siguiente;
  
  BuscarComunidadPorNombre := aux;  // Retorna nil si no se encuentra
end;

{
  BUSCAR USUARIO EN COMUNIDAD
  
  Busca si un usuario específico ya es miembro de una comunidad.
  Recorre la sublista de miembros de la comunidad.
  Complejidad: O(m) donde m = número de miembros en la comunidad
}
function BuscarUsuarioEnComunidad(const comunidad: PComunidad; usuario: PUsuario): Boolean;
var
  aux: PMiembroComunidad;
begin
  aux := comunidad^.miembros.primero;
  
  // Recorrer sublista de miembros comparando punteros
  while (aux <> nil) and (aux^.usuario <> usuario) do
    aux := aux^.siguiente;
  
  BuscarUsuarioEnComunidad := (aux <> nil);  // True si se encontró
end;

{
  AGREGAR USUARIO A COMUNIDAD
  
  Agrega un usuario existente como miembro de una comunidad existente.
  Realiza múltiples validaciones antes de la inserción.
  
  Validaciones:
  1. Usuario válido (no nil)
  2. Comunidad existe
  3. Usuario no está ya en la comunidad
  
  Complejidad: O(n) buscar comunidad + O(m) buscar duplicado + O(m) insertar al final
}
function AgregarUsuarioAComunidad(var lista: TListaComunidades; const nombreComunidad: String; usuario: PUsuario): Boolean;
var
  comunidad: PComunidad;
  nuevoMiembro, aux: PMiembroComunidad;
begin
  // Validación 1: Usuario válido
  if usuario = nil then
  begin
    WriteLn(' Error: Usuario no válido');
    AgregarUsuarioAComunidad := False;
    Exit;
  end;
  
  // Validación 2: Buscar la comunidad en la lista principal
  comunidad := BuscarComunidadPorNombre(lista, nombreComunidad);
  if comunidad = nil then
  begin
    WriteLn(' Error: No se encontró la comunidad "', nombreComunidad, '"');
    AgregarUsuarioAComunidad := False;
    Exit;
  end;
  
  // Validación 3: Verificar que el usuario no esté ya en la comunidad
  if BuscarUsuarioEnComunidad(comunidad, usuario) then
  begin
    WriteLn(' Error: El usuario "', usuario^.email, '" ya está en la comunidad "', nombreComunidad, '"');
    AgregarUsuarioAComunidad := False;
    Exit;
  end;
  
  // Crear nuevo nodo de miembro en la sublista
  New(nuevoMiembro);
  nuevoMiembro^.usuario := usuario;      // Referencia al usuario global (no copia)
  nuevoMiembro^.siguiente := nil;
  
  // Insertar al final de la sublista de miembros
  if comunidad^.miembros.primero = nil then
    comunidad^.miembros.primero := nuevoMiembro  // Primer miembro
  else
  begin
    // Buscar el final de la sublista
    aux := comunidad^.miembros.primero;
    while aux^.siguiente <> nil do
      aux := aux^.siguiente;
    aux^.siguiente := nuevoMiembro;  // Enlazar al final
  end;
  
  WriteLn(' Usuario "', usuario^.email, '" agregado exitosamente a la comunidad "', nombreComunidad, '"');
  AgregarUsuarioAComunidad := True;
end;

{
  CONTAR MIEMBROS COMUNIDAD
  
  Cuenta el número total de miembros en una comunidad específica.
  Recorre toda la sublista de miembros.
  Complejidad: O(m) donde m = número de miembros
}
function ContarMiembrosComunidad(const comunidad: PComunidad): Integer;
var
  aux: PMiembroComunidad;
  contador: Integer;
begin
  contador := 0;
  aux := comunidad^.miembros.primero;
  
  // Recorrer toda la sublista contando nodos
  while aux <> nil do
  begin
    Inc(contador);
    aux := aux^.siguiente;
  end;
  
  ContarMiembrosComunidad := contador;
end;

{
  MOSTRAR MIEMBROS COMUNIDAD
  
  Imprime en consola todos los miembros de una comunidad específica.
  Muestra información detallada de cada usuario miembro.
  Complejidad: O(m) donde m = número de miembros
}
procedure MostrarMiembrosComunidad(const comunidad: PComunidad);
var
  aux: PMiembroComunidad;
  contador: Integer;
begin
  WriteLn(' Miembros de "', comunidad^.nombre, '":');
  aux := comunidad^.miembros.primero;
  contador := 0;
  
  // Verificar si la comunidad tiene miembros
  if aux = nil then
  begin
    WriteLn('    (Sin miembros)');
    Exit;
  end;
  
  // Recorrer e imprimir cada miembro
  while aux <> nil do
  begin
    Inc(contador);
    WriteLn('    ', contador, '. ', aux^.usuario^.nombre, ' (', aux^.usuario^.email, ')');
    aux := aux^.siguiente;
  end;
end;

{
  MOSTRAR COMUNIDADES
  
  Imprime en consola toda la estructura de lista de listas.
  Muestra cada comunidad con su respectiva sublista de miembros.
  
  Complejidad: O(n * m) donde n = comunidades, m = promedio de miembros
}
procedure MostrarComunidades(const lista: TListaComunidades);
var
  aux: PComunidad;
  totalComunidades: Integer;
begin
  WriteLn('=== LISTADO DE COMUNIDADES ===');
  aux := lista.primero;
  totalComunidades := 0;

  // Verificar si hay comunidades
  if aux = nil then
  begin
    WriteLn('  (No hay comunidades creadas)');
    Exit;
  end;
  
  // Recorrer toda la lista principal
  while aux <> nil do
  begin
    Inc(totalComunidades);
    
    // Mostrar información de la comunidad actual
    WriteLn('🏢 Comunidad ID: ', aux^.id, ' | Nombre: "', aux^.nombre, '" | Miembros: ', ContarMiembrosComunidad(aux));
    
    // Mostrar todos los miembros de esta comunidad
    MostrarMiembrosComunidad(aux);
    WriteLn('');  // Línea en blanco para separar comunidades
    
    aux := aux^.siguiente;  // Avanzar a la siguiente comunidad
  end;
  
  WriteLn('📊 Total de comunidades: ', totalComunidades);
end;

{
  LIBERAR MEMORIA COMUNIDADES
  
  Libera toda la memoria asignada dinámicamente para la estructura completa.
  Debe liberar tanto los nodos de la lista principal como todas las sublistas.
  
  Proceso:
  1. Para cada comunidad, liberar toda su sublista de miembros
  2. Liberar el nodo de la comunidad
  3. Continuar hasta liberar toda la lista principal
  
  Complejidad: O(n * m) donde n = comunidades, m = promedio de miembros
}
procedure LiberarMemoriaComunidades(var lista: TListaComunidades);
var
  auxComunidad, tempComunidad: PComunidad;
  auxMiembro, tempMiembro: PMiembroComunidad;
begin
  auxComunidad := lista.primero;
  
  // Recorrer toda la lista principal
  while auxComunidad <> nil do
  begin
    // Liberar todos los miembros de la comunidad actual
    auxMiembro := auxComunidad^.miembros.primero;
    while auxMiembro <> nil do
    begin
      tempMiembro := auxMiembro;
      auxMiembro := auxMiembro^.siguiente;
      Dispose(tempMiembro);  // Liberar nodo de miembro
    end;
    
    // Liberar el nodo de la comunidad
    tempComunidad := auxComunidad;
    auxComunidad := auxComunidad^.siguiente;
    Dispose(tempComunidad);  // Liberar nodo de comunidad
  end;
  
  lista.primero := nil;  // Lista principal queda vacía
end;

end.