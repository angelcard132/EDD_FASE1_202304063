unit comunidades;
{$mode objfpc}{$H+}
interface
uses
  lista_simple, SysUtils;
type
  
  PComunidad = ^TComunidad;
  
  PMiembroComunidad = ^TMiembroComunidad;
  TMiembroComunidad = record
    usuario: PUsuario;  // Referencia al usuario en la lista global
    siguiente: PMiembroComunidad;
  end;
  // Lista de miembros 
  TListaMiembros = record
    primero: PMiembroComunidad;
  end;
  
  TComunidad = record
    id: Integer;
    nombre: String;
    miembros: TListaMiembros;
    siguiente: PComunidad;
  end;
  // Lista principal 
  TListaComunidades = record
    primero: PComunidad;
  end;
// Funciones para gestión de comunidades
procedure InicializarListaComunidades(var lista: TListaComunidades);
procedure InicializarListaMiembros(var lista: TListaMiembros);
function CrearComunidad(var lista: TListaComunidades; const nombre: String): Boolean;
function AgregarUsuarioAComunidad(var lista: TListaComunidades; const nombreComunidad: String; usuario: PUsuario): Boolean;
function BuscarComunidadPorNombre(const lista: TListaComunidades; const nombre: String): PComunidad;
function BuscarUsuarioEnComunidad(const comunidad: PComunidad; usuario: PUsuario): Boolean;
function ObtenerSiguienteIDComunidad(const lista: TListaComunidades): Integer;
procedure MostrarComunidades(const lista: TListaComunidades);
procedure MostrarMiembrosComunidad(const comunidad: PComunidad);
function ContarMiembrosComunidad(const comunidad: PComunidad): Integer;
procedure LiberarMemoriaComunidades(var lista: TListaComunidades);
implementation
procedure InicializarListaComunidades(var lista: TListaComunidades);
begin
  lista.primero := nil;
end;
procedure InicializarListaMiembros(var lista: TListaMiembros);
begin
  lista.primero := nil;
end;
function ObtenerSiguienteIDComunidad(const lista: TListaComunidades): Integer;
var
  aux: PComunidad;
  maxid: Integer;
begin
  maxid := 0;
  aux := lista.primero;
  while aux <> nil do
  begin
    if aux^.id > maxid then maxid := aux^.id;
    aux := aux^.siguiente;
  end;
  ObtenerSiguienteIDComunidad := maxid + 1;
end;
function CrearComunidad(var lista: TListaComunidades; const nombre: String): Boolean;
var
  nueva, aux: PComunidad;
begin
  // Verificar 
  if BuscarComunidadPorNombre(lista, nombre) <> nil then
  begin
    WriteLn('Error: Ya existe una comunidad con el nombre "', nombre, '"');
    CrearComunidad := False;
    Exit;
  end;
  // Crear nueva comunidad
  New(nueva);
  nueva^.id := ObtenerSiguienteIDComunidad(lista);
  nueva^.nombre := nombre;
  InicializarListaMiembros(nueva^.miembros);
  nueva^.siguiente := nil;
  if lista.primero = nil then
    lista.primero := nueva
  else
  begin
    aux := lista.primero;
    while aux^.siguiente <> nil do
      aux := aux^.siguiente;
    aux^.siguiente := nueva;
  end;
  WriteLn('Comunidad "', nombre, '" creada exitosamente con ID: ', nueva^.id);
  CrearComunidad := True;
end;
function BuscarComunidadPorNombre(const lista: TListaComunidades; const nombre: String): PComunidad;
var
  aux: PComunidad;
begin
  aux := lista.primero;
  while (aux <> nil) and (LowerCase(aux^.nombre) <> LowerCase(nombre)) do
    aux := aux^.siguiente;
  BuscarComunidadPorNombre := aux;
end;
function BuscarUsuarioEnComunidad(const comunidad: PComunidad; usuario: PUsuario): Boolean;
var
  aux: PMiembroComunidad;
begin
  aux := comunidad^.miembros.primero;
  while (aux <> nil) and (aux^.usuario <> usuario) do
    aux := aux^.siguiente;
  BuscarUsuarioEnComunidad := (aux <> nil);
end;
function AgregarUsuarioAComunidad(var lista: TListaComunidades; const nombreComunidad: String; usuario: PUsuario): Boolean;
var
  comunidad: PComunidad;
  nuevoMiembro, aux: PMiembroComunidad;
begin
  // Verificar que el usuario exista
  if usuario = nil then
  begin
    WriteLn(' Error: Usuario no válido');
    AgregarUsuarioAComunidad := False;
    Exit;
  end;
  // Buscar la comunidad
  comunidad := BuscarComunidadPorNombre(lista, nombreComunidad);
  if comunidad = nil then
  begin
    WriteLn(' Error: No se encontró la comunidad "', nombreComunidad, '"');
    AgregarUsuarioAComunidad := False;
    Exit;
  end;
  // Verificar si el usuario ya está en la comunidad
  if BuscarUsuarioEnComunidad(comunidad, usuario) then
  begin
    WriteLn(' Error: El usuario "', usuario^.email, '" ya está en la comunidad "', nombreComunidad, '"');
    AgregarUsuarioAComunidad := False;
    Exit;
  end;
  // Agregar usuario a la comunidad
  New(nuevoMiembro);
  nuevoMiembro^.usuario := usuario;
  nuevoMiembro^.siguiente := nil;
  // Insertar al final de la lista de miembros
  if comunidad^.miembros.primero = nil then
    comunidad^.miembros.primero := nuevoMiembro
  else
  begin
    aux := comunidad^.miembros.primero;
    while aux^.siguiente <> nil do
      aux := aux^.siguiente;
    aux^.siguiente := nuevoMiembro;
  end;
  WriteLn(' Usuario "', usuario^.email, '" agregado exitosamente a la comunidad "', nombreComunidad, '"');
  AgregarUsuarioAComunidad := True;
end;
function ContarMiembrosComunidad(const comunidad: PComunidad): Integer;
var
  aux: PMiembroComunidad;
  contador: Integer;
begin
  contador := 0;
  aux := comunidad^.miembros.primero;
  while aux <> nil do
  begin
    Inc(contador);
    aux := aux^.siguiente;
  end;
  ContarMiembrosComunidad := contador;
end;
procedure MostrarMiembrosComunidad(const comunidad: PComunidad);
var
  aux: PMiembroComunidad;
  contador: Integer;
begin
  WriteLn(' Miembros de "', comunidad^.nombre, '":');
  aux := comunidad^.miembros.primero;
  contador := 0;
  if aux = nil then
  begin
    WriteLn('    (Sin miembros)');
    Exit;
  end;
  while aux <> nil do
  begin
    Inc(contador);
    WriteLn('    ', contador, '. ', aux^.usuario^.nombre, ' (', aux^.usuario^.email, ')');
    aux := aux^.siguiente;
  end;
end;
procedure MostrarComunidades(const lista: TListaComunidades);
var
  aux: PComunidad;
  totalComunidades: Integer;
begin
  WriteLn('=== LISTADO DE COMUNIDADES ===');
  aux := lista.primero;
  totalComunidades := 0;

  if aux = nil then
  begin
    WriteLn('  (No hay comunidades creadas)');
    Exit;
  end;
  while aux <> nil do
  begin
    Inc(totalComunidades);
    WriteLn('🏢 Comunidad ID: ', aux^.id, ' | Nombre: "', aux^.nombre, '" | Miembros: ', ContarMiembrosComunidad(aux));
    MostrarMiembrosComunidad(aux);
    WriteLn('');
    aux := aux^.siguiente;
  end;
  
  WriteLn('📊 Total de comunidades: ', totalComunidades);
end;
procedure LiberarMemoriaComunidades(var lista: TListaComunidades);
var
  auxComunidad, tempComunidad: PComunidad;
  auxMiembro, tempMiembro: PMiembroComunidad;
begin
  auxComunidad := lista.primero;
  while auxComunidad <> nil do
  begin
    // Liberar miembros de la comunidad
    auxMiembro := auxComunidad^.miembros.primero;
    while auxMiembro <> nil do
    begin
      tempMiembro := auxMiembro;
      auxMiembro := auxMiembro^.siguiente;
      Dispose(tempMiembro);
    end;
    // Liberar comunidad
    tempComunidad := auxComunidad;
    auxComunidad := auxComunidad^.siguiente;
    Dispose(tempComunidad);
  end;
  lista.primero := nil;
end;
end.