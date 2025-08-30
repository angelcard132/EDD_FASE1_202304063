unit graphviz;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, lista_simple, lista_doble, process;

procedure GenerarGraficoListaSimple(const lista: TListaUsuarios; const nombreArchivo: String);
procedure GenerarGraficoListaDoble(const lista: TListaCorreos; const usuarioEmail: String; const nombreArchivo: String);
procedure GenerarTodosLosGraficos(const usuarios: TListaUsuarios; const correos: TListaCorreos; const usuarioActual: String);
function EjecutarComandoDot(const archivoDot, archivoPng: String): Boolean;

implementation

function EscaparTexto(const texto: String): String;
var
  i: Integer;
  resultado: String;
begin
  resultado := '';
  for i := 1 to Length(texto) do
  begin
    case texto[i] of
      '"': resultado := resultado + '\"';
      '\': resultado := resultado + '\\';
      #10: resultado := resultado + '\n';
      #13: ; // Ignorar retorno de carro
    else
      resultado := resultado + texto[i];
    end;
  end;
  Result := resultado;
end;

function EjecutarComandoDot(const archivoDot, archivoPng: String): Boolean;
var
  proceso: TProcess;
begin
  Result := False;
  try
    proceso := TProcess.Create(nil);
    try
      proceso.Executable := 'dot';
      proceso.Parameters.Add('-Tpng');
      proceso.Parameters.Add(archivoDot);
      proceso.Parameters.Add('-o');
      proceso.Parameters.Add(archivoPng);
      proceso.Options := [poWaitOnExit, poNoConsole];
      
      WriteLn('Ejecutando: dot -Tpng ', archivoDot, ' -o ', archivoPng);
      proceso.Execute;
      
      if proceso.ExitStatus = 0 then
      begin
        WriteLn('✅ Gráfico generado: ', archivoPng);
        Result := True;
      end
      else
      begin
        WriteLn('❌ Error al generar gráfico. Código de salida: ', proceso.ExitStatus);
      end;
    finally
      proceso.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('❌ Error ejecutando dot: ', E.Message);
      WriteLn('💡 Asegúrate de tener GraphViz instalado: sudo apt-get install graphviz');
    end;
  end;
end;

procedure GenerarGraficoListaSimple(const lista: TListaUsuarios; const nombreArchivo: String);
var
  archivo: TextFile;
  aux: PUsuario;
  contador: Integer;
begin
  try
    AssignFile(archivo, nombreArchivo);
    Rewrite(archivo);
    
    WriteLn(archivo, 'digraph ListaSimple {');
    WriteLn(archivo, '    rankdir=LR;');
    WriteLn(archivo, '    node [shape=record, style=filled, fillcolor=lightblue];');
    WriteLn(archivo, '    edge [color=blue];');
    WriteLn(archivo, '');
    WriteLn(archivo, '    // Título');
    WriteLn(archivo, '    title [label="Lista Simple de Usuarios", shape=plaintext, fontsize=16, fontweight=bold];');
    WriteLn(archivo, '');
    
    aux := lista.primero;
    contador := 0;
    
    if aux = nil then
    begin
      WriteLn(archivo, '    empty [label="Lista Vacía", fillcolor=lightgray];');
    end
    else
    begin
      // Generar nodos
      while aux <> nil do
      begin
        WriteLn(archivo, '    user', contador, ' [label="ID: ', aux^.id, '|Nombre: ', EscaparTexto(aux^.nombre), '|Usuario: ', EscaparTexto(aux^.usuario), '|Email: ', EscaparTexto(aux^.email), '"];');
        aux := aux^.siguiente;
        Inc(contador);
      end;
      
      WriteLn(archivo, '');
      WriteLn(archivo, '    // Conexiones');
      
      // Generar conexiones
      for contador := 0 to contador - 2 do
      begin
        WriteLn(archivo, '    user', contador, ' -> user', contador + 1, ';');
      end;
    end;
    
    WriteLn(archivo, '}');
    CloseFile(archivo);
    
    WriteLn('📄 Archivo DOT generado: ', nombreArchivo);
    
  except
    on E: Exception do
      WriteLn('❌ Error generando archivo DOT: ', E.Message);
  end;
end;

procedure GenerarGraficoListaDoble(const lista: TListaCorreos; const usuarioEmail: String; const nombreArchivo: String);
var
  archivo: TextFile;
  aux: PCorreo;
  contador, totalCorreos: Integer;
begin
  try
    AssignFile(archivo, nombreArchivo);
    Rewrite(archivo);
    
    WriteLn(archivo, 'digraph ListaDobleCorreos {');
    WriteLn(archivo, '    rankdir=LR;');
    WriteLn(archivo, '    node [shape=record, style=filled, fillcolor=lightgreen];');
    WriteLn(archivo, '    edge [color=darkgreen];');
    WriteLn(archivo, '');
    WriteLn(archivo, '    // Título');
    WriteLn(archivo, '    title [label="Correos de: ', EscaparTexto(usuarioEmail), '", shape=plaintext, fontsize=16, fontweight=bold];');
    WriteLn(archivo, '');
    
    aux := lista.primero;
    contador := 0;
    totalCorreos := 0;
    
    // Contar correos para el usuario
    while aux <> nil do
    begin
      if LowerCase(aux^.destinatario) = LowerCase(usuarioEmail) then
        Inc(totalCorreos);
      aux := aux^.siguiente;
    end;
    
    if totalCorreos = 0 then
    begin
      WriteLn(archivo, '    empty [label="Sin correos en bandeja", fillcolor=lightgray];');
      WriteLn(archivo, '    stats [label="Total de correos: 0", shape=plaintext, fontsize=12];');
    end
    else
    begin
      // Generar nodos solo para correos del usuario logueado
      aux := lista.primero;
      while aux <> nil do
      begin
        if LowerCase(aux^.destinatario) = LowerCase(usuarioEmail) then
        begin
          WriteLn(archivo, '    correo', contador, ' [label="ID: ', aux^.id, '|De: ', EscaparTexto(aux^.remitente), '|Asunto: ', EscaparTexto(aux^.asunto), '|Estado: ', aux^.estado, '"];');
          Inc(contador);
        end;
        aux := aux^.siguiente;
      end;
      
      WriteLn(archivo, '');
      WriteLn(archivo, '    // Estadísticas');
      WriteLn(archivo, '    stats [label="Total de correos en bandeja: ', totalCorreos, '", shape=plaintext, fontsize=12, fontcolor=blue];');
      WriteLn(archivo, '');
      WriteLn(archivo, '    // Conexiones hacia adelante');
      
      // Generar conexiones hacia adelante
      for contador := 0 to contador - 2 do
      begin
        WriteLn(archivo, '    correo', contador, ' -> correo', contador + 1, ' [label="sig"];');
      end;
      
      WriteLn(archivo, '');
      WriteLn(archivo, '    // Conexiones hacia atrás');
      
      // Generar conexiones hacia atrás
      for contador := 1 to contador - 1 do
      begin
        WriteLn(archivo, '    correo', contador, ' -> correo', contador - 1, ' [label="ant", color=red, style=dashed];');
      end;
    end;
    
    WriteLn(archivo, '}');
    CloseFile(archivo);
    
    WriteLn('📄 Archivo DOT generado: ', nombreArchivo);
    WriteLn('📊 Correos encontrados para ', usuarioEmail, ': ', totalCorreos);
    
  except
    on E: Exception do
      WriteLn('❌ Error generando archivo DOT: ', E.Message);
  end;
end;

procedure GenerarTodosLosGraficos(const usuarios: TListaUsuarios; const correos: TListaCorreos; const usuarioActual: String);
var
  rutaBase: String;
  archivoDotUsuarios, archivoPngUsuarios: String;
  archivoDotCorreos, archivoPngCorreos: String;
begin
  rutaBase := '/home/angel/Desktop/EDD_FASE1_202304063/Tareas/Tarea 1/';
  
  // Rutas para lista simple (usuarios)
  archivoDotUsuarios := rutaBase + 'lista_usuarios.dot';
  archivoPngUsuarios := rutaBase + 'lista_usuarios.png';
  
  // Rutas para lista doble (correos del usuario actual)
  archivoDotCorreos := rutaBase + 'correos_' + StringReplace(usuarioActual, '@', '_', [rfReplaceAll]) + '.dot';
  archivoPngCorreos := rutaBase + 'correos_' + StringReplace(usuarioActual, '@', '_', [rfReplaceAll]) + '.png';
  
  WriteLn('🎨 Generando gráficos de las estructuras de datos...');
  WriteLn('👤 Usuario activo: ', usuarioActual);
  WriteLn('');
  
  // Generar gráfico de usuarios (lista simple)
  WriteLn('📊 Generando gráfico de Lista Simple (Usuarios)...');
  GenerarGraficoListaSimple(usuarios, archivoDotUsuarios);
  if EjecutarComandoDot(archivoDotUsuarios, archivoPngUsuarios) then
    WriteLn('✅ Gráfico de usuarios guardado en: ', archivoPngUsuarios);
  
  WriteLn('');
  
  // Generar gráfico de correos (lista doble - solo del usuario actual)
  WriteLn('📊 Generando gráfico de Correos del Usuario (Lista Doble)...');
  GenerarGraficoListaDoble(correos, usuarioActual, archivoDotCorreos);
  if EjecutarComandoDot(archivoDotCorreos, archivoPngCorreos) then
    WriteLn('✅ Gráfico de correos guardado en: ', archivoPngCorreos);
  
  WriteLn('');
  WriteLn('🎉 Generación de gráficos completada!');
  WriteLn('📁 Los archivos se encuentran en: ', rutaBase);
end;

end.
