{
  MÓDULO DE CARGA JSON
  
  Este módulo se encarga de cargar datos desde archivos JSON y poblar
  las estructuras de datos del sistema (usuarios y correos).
  
  Soporta múltiples formatos JSON para flexibilidad:
  - Formato estándar: Array simple de usuarios/correos
  - Formato por usuario: Correos agrupados por usuario destinatario
  
  Utiliza la biblioteca fpjson de Free Pascal para parsing JSON.
}
unit json_loader;

{$mode objfpc}{$H+}

interface

uses
  Classes,       // Para TStringList
  SysUtils,      // Funciones del sistema
  fpjson,        // Parser JSON de Free Pascal
  jsonparser,    // Parser JSON adicional
  lista_simple,  // Para cargar usuarios
  lista_doble;   // Para cargar correos

// Cargar usuarios desde archivo JSON formato estándar
procedure CargarUsuariosDesdeJSON(const archivo: String; var lista: TListaUsuarios);

// Cargar correos desde archivo JSON formato estándar
procedure CargarCorreosDesdeJSON(const archivo: String; var lista: TListaCorreos);

// Cargar correos desde archivo JSON formato por usuario (más complejo)
procedure CargarCorreosDesdeJSON2(const archivo: String; var lista: TListaCorreos; var usuarios: TListaUsuarios);

implementation



procedure CargarUsuariosDesdeJSON(const archivo: String; var lista: TListaUsuarios);
var
  data: TStringList;        // Para cargar el archivo completo
  json: TJSONData;          // Objeto JSON raíz
  arr: TJSONArray;          // Array de usuarios
  obj: TJSONObject;         // Objeto individual de usuario
  i: Integer;               // Contador de iteración
begin
  // Verificar que el archivo exista
  if not FileExists(archivo) then
  begin
    WriteLn('El archivo JSON no existe: ', archivo);
    Exit;
  end;

  data := TStringList.Create;
  try
    // Cargar todo el archivo en memoria
    data.LoadFromFile(archivo);
    
    // Parsear el JSON completo
    json := GetJSON(data.Text);
    try
      // Buscar el array "usuarios" en la estructura JSON
      arr := TJSONArray(json.FindPath('usuarios'));
      if arr <> nil then
      begin
        WriteLn('📂 Cargando usuarios desde formato estándar...');
        
        // Iterar sobre cada usuario en el array
        for i := 0 to arr.Count - 1 do
        begin
          obj := arr.Objects[i];  // Obtener objeto usuario individual
          
          // Insertar usuario en la lista simple usando los campos JSON
          InsertarUsuario(lista,
            obj.Get('id', 0),           // ID con valor por defecto 0
            obj.Get('nombre', ''),      // Nombre con string vacío por defecto
            obj.Get('usuario', ''),     // Usuario con string vacío por defecto
            obj.Get('email', ''),       // Email con string vacío por defecto
            obj.Get('telefono', ''),    // Teléfono con string vacío por defecto
            obj.Get('password', '')     // Password con string vacío por defecto
          );
          WriteLn('  ✅ Usuario cargado: ', obj.Get('email', ''));
        end;
        WriteLn('📊 Total usuarios cargados: ', arr.Count);
      end;
    finally
      json.Free;  // Liberar memoria del objeto JSON
    end;
  finally
    data.Free;    // Liberar memoria del StringList
  end;
end;

{
  CARGAR CORREOS DESDE JSON
  
  Carga correos desde un archivo JSON con formato estándar:
  {
    "correos": [
      {"id": 1, "remitente": "...", "destinatario": "...", "estado": "...", "asunto": "...", "fecha": "...", "contenido": "..."},
      ...
    ]
  }
  
  Complejidad: O(n) donde n = número de correos en el archivo
}
procedure CargarCorreosDesdeJSON(const archivo: String; var lista: TListaCorreos);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
begin
  // Verificar existencia del archivo
  if not FileExists(archivo) then
  begin
    WriteLn('El archivo JSON no existe: ', archivo);
    Exit;
  end;

  data := TStringList.Create;
  try
    data.LoadFromFile(archivo);
    json := GetJSON(data.Text);
    try
      // Buscar array "correos"
      arr := TJSONArray(json.FindPath('correos'));
      if arr <> nil then
      begin
        WriteLn('📂 Cargando correos desde formato estándar...');
        
        // Iterar sobre cada correo
        for i := 0 to arr.Count - 1 do
        begin
          obj := arr.Objects[i];
          
          // Insertar correo en la lista doble
          InsertarCorreo(lista,
            obj.Get('id', 0),
            obj.Get('remitente', ''),
            obj.Get('destinatario', ''),
            obj.Get('estado', 'NL'),     // Estado por defecto: No Leído
            obj.Get('asunto', ''),
            obj.Get('fecha', ''),
            obj.Get('contenido', '')
          );
          WriteLn('  ✅ Correo cargado: ', obj.Get('asunto', ''));
        end;
        WriteLn('📊 Total correos cargados: ', arr.Count);
      end;
    finally
      json.Free;
    end;
  finally
    data.Free;
  end;
end;

{
  CARGAR CORREOS DESDE JSON FORMATO 2
  
  Carga correos desde un archivo JSON con formato agrupado por usuario:
  {
    "correos": [
      {
        "usuario_id": 1,
        "bandeja_entrada": [
          {"id": 101, "remitente": "...", "estado": "leído", "asunto": "...", "fecha": "...", "mensaje": "..."},
          ...
        ]
      },
      ...
    ]
  }
  
  Este formato es más complejo porque requiere:
  1. Buscar el usuario correspondiente al usuario_id
  2. Convertir estados del formato texto al formato interno
  3. Mapear "mensaje" a "contenido"
  
  Complejidad: O(n * m * u) donde n = usuarios con correos, m = correos por usuario, u = usuarios totales
}
procedure CargarCorreosDesdeJSON2(const archivo: String; var lista: TListaCorreos; var usuarios: TListaUsuarios);
var
  data: TStringList;
  json: TJSONData;
  correosArray: TJSONArray;      // Array principal de usuarios con correos
  usuarioObj: TJSONObject;       // Objeto de usuario individual
  bandejaArray: TJSONArray;      // Array de correos del usuario
  correoObj: TJSONObject;        // Objeto de correo individual
  i, j: Integer;                 // Contadores de iteración
  usuarioId: Integer;            // ID del usuario destinatario
  usuario: PUsuario;             // Puntero al usuario encontrado
  estado, destinatario: String;  // Variables de conversión
  totalCorreos: Integer;         // Contador total de correos procesados
begin
  if not FileExists(archivo) then
  begin
    WriteLn('El archivo JSON no existe: ', archivo);
    Exit;
  end;

  data := TStringList.Create;
  totalCorreos := 0;
  try
    data.LoadFromFile(archivo);
    json := GetJSON(data.Text);
    try
      correosArray := TJSONArray(json.FindPath('correos'));
      if correosArray <> nil then
      begin
        WriteLn('📂 Cargando correos desde formato por usuario...');
        
        // Iterar sobre cada usuario que tiene correos
        for i := 0 to correosArray.Count - 1 do
        begin
          usuarioObj := correosArray.Objects[i];
          usuarioId := usuarioObj.Get('usuario_id', 0);
          
          WriteLn('🔍 Buscando usuario con ID: ', usuarioId);
          
          // Buscar el usuario correspondiente en la lista de usuarios
          // Esta es una búsqueda O(u) donde u = número de usuarios
          usuario := nil;
          if usuarios.primero <> nil then
          begin
            usuario := usuarios.primero;
            while (usuario <> nil) and (usuario^.id <> usuarioId) do
              usuario := usuario^.siguiente;
          end;

          // Si se encontró el usuario, procesar sus correos
          if usuario <> nil then
          begin
            destinatario := usuario^.email;
            WriteLn('  📧 Procesando correos para: ', destinatario, ' (ID: ', usuarioId, ')');
            
            // Obtener array de correos del usuario
            bandejaArray := TJSONArray(usuarioObj.FindPath('bandeja_entrada'));
            if bandejaArray <> nil then
            begin
              WriteLn('    📥 Correos en bandeja: ', bandejaArray.Count);
              
              // Procesar cada correo del usuario
              for j := 0 to bandejaArray.Count - 1 do
              begin
                correoObj := bandejaArray.Objects[j];
                
                // Convertir estado del formato JSON al formato interno
                if correoObj.Get('estado', '') = 'leído' then
                  estado := 'L'      // Leído
                else if correoObj.Get('estado', '') = 'no leído' then
                  estado := 'NL'     // No Leído
                else
                  estado := 'NL';    // Por defecto: No Leído

                // Insertar correo en la lista doble global
                InsertarCorreo(lista,
                  correoObj.Get('id', 0),
                  correoObj.Get('remitente', ''),
                  destinatario,  // El destinatario es el usuario actual
                  estado,
                  correoObj.Get('asunto', ''),
                  correoObj.Get('fecha', ''),
                  correoObj.Get('mensaje', '')  // En formato 2 se llama 'mensaje', no 'contenido'
                );
                
                WriteLn('    ✅ Correo: ', correoObj.Get('asunto', ''), ' (', estado, ')');
                Inc(totalCorreos);
              end;
            end
            else
            begin
              WriteLn('    ⚠️ No se encontró bandeja_entrada para usuario ID ', usuarioId);
            end;
          end
          else
          begin
            WriteLn('  ⚠️ Usuario con ID ', usuarioId, ' no encontrado en la lista');
          end;
        end;
        WriteLn('📊 Total correos cargados desde formato por usuario: ', totalCorreos);
      end
      else
      begin
        WriteLn('⚠️ No se encontró el array "correos" en el JSON');
      end;
    finally
      json.Free;
    end;
  finally
    data.Free;
  end;
end;

end.
