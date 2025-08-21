unit graphviz;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, lista_simple, lista_doble, lista_circular, cola, pila, globals;

procedure GenerarGraficoUsuarios(const archivo: String);
procedure GenerarGraficoCorreos(const archivo: String);
procedure GenerarGraficoContactos(const archivo: String);
procedure GenerarGraficoCola(const archivo: String);
procedure GenerarGraficoPapelera(const archivo: String);
procedure GenerarGraficoMatrizDispersa(const archivo: String);
procedure GenerarTodosLosGraficos;

implementation

function LimpiarTextoGraphviz(const texto: String): String;
var
  i: Integer;
  resultado: String;
begin
  resultado := '';
  for i := 1 to Length(texto) do
  begin
    case texto[i] of
      '"': resultado += '\"';
      '\': resultado += '\\';
      #10, #13: resultado += ' ';
      '<', '>': resultado += '_';
      '{', '}': resultado += '_';
      '|': resultado += '_';
      else
        if Ord(texto[i]) >= 32 then
          resultado += texto[i]
        else
          resultado += '_';
    end;
  end;
  Result := resultado;
end;

function EjecutarComando(const comando: String): Boolean;
var
  proceso: TProcess;
begin
  Result := False;
  proceso := TProcess.Create(nil);
  try
    {$IFDEF WINDOWS}
    proceso.Executable := 'cmd';
    proceso.Parameters.Add('/c');
    proceso.Parameters.Add(comando);
    {$ELSE}
    proceso.Executable := '/bin/bash';
    proceso.Parameters.Add('-c');
    proceso.Parameters.Add(comando);
    {$ENDIF}
    
    proceso.Options := [poWaitOnExit, poUsePipes];
    
    try
      proceso.Execute;
      Result := (proceso.ExitStatus = 0);
    except
      on E: Exception do
      begin
        WriteLn('⚠️ Error ejecutando comando: ', E.Message);
        Result := False;
      end;
    end;
  finally
    proceso.Free;
  end;
end;

function ComprobarGraphviz: Boolean;
begin
  WriteLn('🔍 Verificando si Graphviz está instalado...');
  
  {$IFDEF WINDOWS}
  Result := EjecutarComando('dot -V');
  {$ELSE}
  Result := EjecutarComando('which dot');
  {$ENDIF}
  
  if Result then
    WriteLn('✅ Graphviz encontrado')
  else
  begin
    WriteLn('❌ Graphviz no está instalado o no está en PATH');
    WriteLn('💡 Para instalar Graphviz:');
    {$IFDEF WINDOWS}
    WriteLn('   - Descargar desde: https://graphviz.org/download/');
    WriteLn('   - O usar chocolatey: choco install graphviz');
    {$ELSE}
    WriteLn('   - Ubuntu/Debian: sudo apt install graphviz');
    WriteLn('   - CentOS/RHEL: sudo yum install graphviz');
    WriteLn('   - macOS: brew install graphviz');
    {$ENDIF}
  end;
end;

procedure GenerarGraficoUsuarios(const archivo: String);
var
  f: TextFile;
  aux: PUsuario;
  contador: Integer;
begin
  AssignFile(f, archivo);
  Rewrite(f);
  
  WriteLn(f, 'digraph ListaUsuarios {');
  WriteLn(f, '  rankdir=LR;');
  WriteLn(f, '  node [shape=record, style=filled, fillcolor=lightblue];');
  WriteLn(f, '  edge [color=blue, style=bold];');
  WriteLn(f, '');
  WriteLn(f, '  // Título');
  WriteLn(f, '  titulo [label="LISTA SIMPLE - USUARIOS", shape=box, style=filled, fillcolor=yellow];');
  WriteLn(f, '');
  
  if UsuariosGlobal.primero = nil then
  begin
    WriteLn(f, '  vacia [label="Lista Vacía", shape=box, style=filled, fillcolor=red];');
    WriteLn(f, '  titulo -> vacia;');
  end
  else
  begin
    aux := UsuariosGlobal.primero;
    contador := 0;
    
    // Generar nodos
    while aux <> nil do
    begin
      WriteLn(f, '  usuario', contador, ' [label="ID: ', aux^.id, 
              '|Nombre: ', LimpiarTextoGraphviz(aux^.nombre),
              '|Usuario: ', LimpiarTextoGraphviz(aux^.usuario),
              '|Email: ', LimpiarTextoGraphviz(aux^.email),
              '|Tel: ', LimpiarTextoGraphviz(aux^.telefono), '"];');
      Inc(contador);
      aux := aux^.siguiente;
    end;
    
    WriteLn(f, '');
    WriteLn(f, '  // Conexiones');
    WriteLn(f, '  titulo -> usuario0;');
    
    // Generar conexiones
    for contador := 0 to contador - 2 do
      WriteLn(f, '  usuario', contador, ' -> usuario', contador + 1, ';');
      
    WriteLn(f, '  usuario', contador - 1, ' -> null [style=dashed];');
    WriteLn(f, '  null [label="NULL", shape=box, style=filled, fillcolor=gray];');
  end;
  
  WriteLn(f, '}');
  CloseFile(f);
  WriteLn('📊 Gráfico de usuarios generado: ', archivo);
end;

procedure GenerarGraficoCorreos(const archivo: String);
var
  f: TextFile;
  aux: PCorreo;
  contador: Integer;
begin
  AssignFile(f, archivo);
  Rewrite(f);
  
  WriteLn(f, 'digraph ListaCorreos {');
  WriteLn(f, '  rankdir=LR;');
  WriteLn(f, '  node [shape=record, style=filled, fillcolor=lightgreen];');
  WriteLn(f, '  edge [color=green, style=bold];');
  WriteLn(f, '');
  WriteLn(f, '  // Título');
  WriteLn(f, '  titulo [label="LISTA DOBLEMENTE ENLAZADA - CORREOS", shape=box, style=filled, fillcolor=yellow];');
  WriteLn(f, '');
  
  if CorreosGlobal.primero = nil then
  begin
    WriteLn(f, '  vacia [label="Lista Vacía", shape=box, style=filled, fillcolor=red];');
    WriteLn(f, '  titulo -> vacia;');
  end
  else
  begin
    aux := CorreosGlobal.primero;
    contador := 0;
    
    // Generar nodos
    while aux <> nil do
    begin
      WriteLn(f, '  correo', contador, ' [label="ID: ', aux^.id,
              '|De: ', LimpiarTextoGraphviz(aux^.remitente),
              '|Para: ', LimpiarTextoGraphviz(aux^.destinatario),
              '|Asunto: ', LimpiarTextoGraphviz(aux^.asunto),
              '|Estado: ', aux^.estado,
              '|Fecha: ', LimpiarTextoGraphviz(aux^.fecha), '"];');
      Inc(contador);
      aux := aux^.siguiente;
    end;
    
    WriteLn(f, '');
    WriteLn(f, '  // Conexiones hacia adelante');
    WriteLn(f, '  titulo -> correo0;');
    
    for contador := 0 to contador - 2 do
      WriteLn(f, '  correo', contador, ' -> correo', contador + 1, ' [label="sig"];');
      
    WriteLn(f, '  correo', contador - 1, ' -> null [style=dashed];');
    WriteLn(f, '  null [label="NULL", shape=box, style=filled, fillcolor=gray];');
  end;
  
  WriteLn(f, '}');
  CloseFile(f);
  WriteLn('📊 Gráfico de correos generado: ', archivo);
end;

procedure GenerarGraficoContactos(const archivo: String);
var
  f: TextFile;
  aux: PContacto;
  contador: Integer;
begin
  AssignFile(f, archivo);
  Rewrite(f);
  
  WriteLn(f, 'digraph ListaContactos {');
  WriteLn(f, '  rankdir=LR;');
  WriteLn(f, '  node [shape=record, style=filled, fillcolor=lightyellow];');
  WriteLn(f, '  edge [color=orange, style=bold];');
  WriteLn(f, '');
  WriteLn(f, '  // Título');
  WriteLn(f, '  titulo [label="LISTA CIRCULAR - CONTACTOS\\nUsuario: ', 
         LimpiarTextoGraphviz(UsuarioActivo.email), '", shape=box, style=filled, fillcolor=yellow];');
  WriteLn(f, '');
  
  if ContactosUsuarioActivo.primero = nil then
  begin
    WriteLn(f, '  vacia [label="Lista Vacía", shape=box, style=filled, fillcolor=red];');
    WriteLn(f, '  titulo -> vacia;');
  end
  else
  begin
    aux := ContactosUsuarioActivo.primero;
    contador := 0;
    
    // Generar nodos
    repeat
      WriteLn(f, '  contacto', contador, ' [label="ID: ', aux^.id,
              '|Nombre: ', LimpiarTextoGraphviz(aux^.nombre),
              '|Email: ', LimpiarTextoGraphviz(aux^.email), '"];');
      aux := aux^.siguiente;
      Inc(contador);
    until (aux = ContactosUsuarioActivo.primero) or (contador >= 20);
    
    WriteLn(f, '');
    WriteLn(f, '  // Conexiones circulares');
    WriteLn(f, '  titulo -> contacto0;');
    
    // Conexiones hacia adelante
    for contador := 0 to contador - 2 do
      WriteLn(f, '  contacto', contador, ' -> contacto', contador + 1, ' [label="sig"];');
      
    // Conexión circular (último al primero)
    WriteLn(f, '  contacto', contador - 1, ' -> contacto0 [label="sig", color=red, style=dashed];');
  end;
  
  WriteLn(f, '}');
  CloseFile(f);
  WriteLn('📊 Gráfico de contactos generado: ', archivo);
end;

procedure GenerarGraficoCola(const archivo: String);
var
  f: TextFile;
  aux: PCorreoCola;
  contador: Integer;
begin
  AssignFile(f, archivo);
  Rewrite(f);
  
  WriteLn(f, 'digraph ColaCorreos {');
  WriteLn(f, '  rankdir=LR;');
  WriteLn(f, '  node [shape=record, style=filled, fillcolor=lightcyan];');
  WriteLn(f, '  edge [color=blue, style=bold];');
  WriteLn(f, '');
  WriteLn(f, '  // Título');
  WriteLn(f, '  titulo [label="COLA (FIFO) - CORREOS PROGRAMADOS\\nUsuario: ', 
         LimpiarTextoGraphviz(UsuarioActivo.email), '", shape=box, style=filled, fillcolor=yellow];');
  WriteLn(f, '');
  WriteLn(f, '  frente [label="FRENTE", shape=box, style=filled, fillcolor=green];');
  WriteLn(f, '  final [label="FINAL", shape=box, style=filled, fillcolor=red];');
  WriteLn(f, '');
  
  if ColaProgramadosUsuarioActivo.frente = nil then
  begin
    WriteLn(f, '  vacia [label="Cola Vacía", shape=box, style=filled, fillcolor=red];');
    WriteLn(f, '  titulo -> vacia;');
    WriteLn(f, '  frente -> vacia;');
    WriteLn(f, '  final -> vacia;');
  end
  else
  begin
    aux := ColaProgramadosUsuarioActivo.frente;
    contador := 0;
    
    // Generar nodos
    while aux <> nil do
    begin
      WriteLn(f, '  correo', contador, ' [label="ID: ', aux^.id,
              '|Para: ', LimpiarTextoGraphviz(aux^.destinatario),
              '|Asunto: ', LimpiarTextoGraphviz(aux^.asunto),
              '|Fecha: ', LimpiarTextoGraphviz(aux^.fecha), '"];');
      Inc(contador);
      aux := aux^.siguiente;
    end;
    
    WriteLn(f, '');
    WriteLn(f, '  // Conexiones');
    WriteLn(f, '  titulo -> frente;');
    WriteLn(f, '  frente -> correo0 [color=green];');
    WriteLn(f, '  final -> correo', contador - 1, ' [color=red];');
    
    // Conexiones entre nodos
    for contador := 0 to contador - 2 do
      WriteLn(f, '  correo', contador, ' -> correo', contador + 1, ';');
      
    WriteLn(f, '  correo', contador - 1, ' -> null [style=dashed];');
    WriteLn(f, '  null [label="NULL", shape=box, style=filled, fillcolor=gray];');
  end;
  
  WriteLn(f, '}');
  CloseFile(f);
  WriteLn('📊 Gráfico de cola generado: ', archivo);
end;

procedure GenerarGraficoPapelera(const archivo: String);
var
  f: TextFile;
  aux: PCorreo;
  contador, correosEliminados: Integer;
begin
  AssignFile(f, archivo);
  Rewrite(f);
  
  WriteLn(f, 'digraph Papelera {');
  WriteLn(f, '  rankdir=TB;');
  WriteLn(f, '  node [shape=record, style=filled, fillcolor=lightcoral];');
  WriteLn(f, '  edge [color=red, style=bold];');
  WriteLn(f, '');
  WriteLn(f, '  // Título');
  WriteLn(f, '  titulo [label="PILA (LIFO) - PAPELERA\\nUsuario: ', 
         LimpiarTextoGraphviz(UsuarioActivo.email), '", shape=box, style=filled, fillcolor=yellow];');
  WriteLn(f, '');
  WriteLn(f, '  tope [label="TOPE", shape=box, style=filled, fillcolor=red];');
  WriteLn(f, '');
  
  // Contar correos eliminados
  correosEliminados := 0;
  aux := CorreosGlobal.primero;
  while aux <> nil do
  begin
    if (aux^.estado = 'DEL') and 
       ((LowerCase(aux^.destinatario) = LowerCase(UsuarioActivo.email)) or 
        (LowerCase(aux^.remitente) = LowerCase(UsuarioActivo.email))) then
      Inc(correosEliminados);
    aux := aux^.siguiente;
  end;
  
  if correosEliminados = 0 then
  begin
    WriteLn(f, '  vacia [label="Papelera Vacía", shape=box, style=filled, fillcolor=gray];');
    WriteLn(f, '  titulo -> vacia;');
    WriteLn(f, '  tope -> vacia;');
  end
  else
  begin
    aux := CorreosGlobal.primero;
    contador := 0;
    
    // Generar nodos de correos eliminados
    while aux <> nil do
    begin
      if (aux^.estado = 'DEL') and 
         ((LowerCase(aux^.destinatario) = LowerCase(UsuarioActivo.email)) or 
          (LowerCase(aux^.remitente) = LowerCase(UsuarioActivo.email))) then
      begin
        WriteLn(f, '  eliminado', contador, ' [label="ID: ', aux^.id,
                '|De: ', LimpiarTextoGraphviz(aux^.remitente),
                '|Para: ', LimpiarTextoGraphviz(aux^.destinatario),
                '|Asunto: ', LimpiarTextoGraphviz(aux^.asunto),
                '|ELIMINADO"];');
        Inc(contador);
      end;
      aux := aux^.siguiente;
    end;
    
    WriteLn(f, '');
    WriteLn(f, '  // Conexiones de pila (LIFO)');
    WriteLn(f, '  titulo -> tope;');
    WriteLn(f, '  tope -> eliminado', contador - 1, ' [color=red];');
    
    // Conexiones de pila (último eliminado arriba)
    for contador := contador - 1 downto 1 do
      WriteLn(f, '  eliminado', contador, ' -> eliminado', contador - 1, ';');
      
    WriteLn(f, '  eliminado0 -> null [style=dashed];');
    WriteLn(f, '  null [label="NULL", shape=box, style=filled, fillcolor=gray];');
  end;
  
  WriteLn(f, '}');
  CloseFile(f);
  WriteLn('📊 Gráfico de papelera generado: ', archivo);
end;

procedure GenerarGraficoMatrizDispersa(const archivo: String);
var
  f: TextFile;
  aux: PCorreo;
  remitentes, destinatarios: array of String;
  matriz: array of array of Integer;
  i, j, numRemitentes, numDestinatarios: Integer;
  remitenteIdx, destinatarioIdx: Integer;
  encontrado: Boolean;
  correosEnviados: Integer;
begin
  AssignFile(f, archivo);
  Rewrite(f);
  
  WriteLn(f, 'digraph MatrizDispersa {');
  WriteLn(f, '  rankdir=TB;');
  WriteLn(f, '  node [shape=record, style=filled];');
  WriteLn(f, '  edge [color=purple, style=bold];');
  WriteLn(f, '');
  WriteLn(f, '  // Título');
  WriteLn(f, '  titulo [label="MATRIZ DISPERSA - CORREOS ENVIADOS\\nFilas: Destinatarios | Columnas: Remitentes", shape=box, style=filled, fillcolor=yellow];');
  WriteLn(f, '');
  
  // Contar correos enviados (no eliminados)
  correosEnviados := 0;
  aux := CorreosGlobal.primero;
  while aux <> nil do
  begin
    if aux^.estado <> 'DEL' then
      Inc(correosEnviados);
    aux := aux^.siguiente;
  end;
  
  if correosEnviados = 0 then
  begin
    WriteLn(f, '  vacia [label="No hay correos enviados para generar matriz", shape=box, style=filled, fillcolor=red];');
    WriteLn(f, '  titulo -> vacia;');
  end
  else
  begin
    // Inicializar arrays dinámicos
    SetLength(remitentes, 0);
    SetLength(destinatarios, 0);
    numRemitentes := 0;
    numDestinatarios := 0;
    
    // Recopilar todos los remitentes y destinatarios únicos de CORREOS ENVIADOS (no eliminados)
    aux := CorreosGlobal.primero;
    while aux <> nil do
    begin
      if aux^.estado <> 'DEL' then  // Solo correos no eliminados (correos enviados válidos)
      begin
        // Verificar remitente único
        encontrado := False;
        for i := 0 to numRemitentes - 1 do
        begin
          if LowerCase(remitentes[i]) = LowerCase(aux^.remitente) then
          begin
            encontrado := True;
            Break;
          end;
        end;
        if not encontrado then
        begin
          SetLength(remitentes, numRemitentes + 1);
          remitentes[numRemitentes] := aux^.remitente;
          Inc(numRemitentes);
        end;
        
        // Verificar destinatario único
        encontrado := False;
        for i := 0 to numDestinatarios - 1 do
        begin
          if LowerCase(destinatarios[i]) = LowerCase(aux^.destinatario) then
          begin
            encontrado := True;
            Break;
          end;
        end;
        if not encontrado then
        begin
          SetLength(destinatarios, numDestinatarios + 1);
          destinatarios[numDestinatarios] := aux^.destinatario;
          Inc(numDestinatarios);
        end;
      end;
      aux := aux^.siguiente;
    end;
    
    // Inicializar matriz con ceros
    SetLength(matriz, numDestinatarios);
    for i := 0 to numDestinatarios - 1 do
    begin
      SetLength(matriz[i], numRemitentes);
      for j := 0 to numRemitentes - 1 do
        matriz[i][j] := 0;
    end;
    
    // Llenar matriz contando SOLO correos enviados (no eliminados)
    aux := CorreosGlobal.primero;
    while aux <> nil do
    begin
      if aux^.estado <> 'DEL' then  // Solo correos enviados válidos
      begin
        // Encontrar índice del remitente
        remitenteIdx := -1;
        for j := 0 to numRemitentes - 1 do
        begin
          if LowerCase(remitentes[j]) = LowerCase(aux^.remitente) then
          begin
            remitenteIdx := j;
            Break;
          end;
        end;
        
        // Encontrar índice del destinatario
        destinatarioIdx := -1;
        for i := 0 to numDestinatarios - 1 do
        begin
          if LowerCase(destinatarios[i]) = LowerCase(aux^.destinatario) then
          begin
            destinatarioIdx := i;
            Break;
          end;
        end;
        
        // Incrementar contador en la matriz
        if (remitenteIdx >= 0) and (destinatarioIdx >= 0) then
          Inc(matriz[destinatarioIdx][remitenteIdx]);
      end;
      aux := aux^.siguiente;
    end;
    
    // Generar encabezados de columnas (remitentes)
    WriteLn(f, '  // Encabezados de columnas (Remitentes que enviaron correos)');
    WriteLn(f, '  subgraph cluster_remitentes {');
    WriteLn(f, '    label="REMITENTES (Columnas)";');
    WriteLn(f, '    style=filled;');
    WriteLn(f, '    fillcolor=lightblue;');
    WriteLn(f, '    rank=same;');
    for j := 0 to numRemitentes - 1 do
    begin
      WriteLn(f, '    rem', j, ' [label="', LimpiarTextoGraphviz(remitentes[j]), '", fillcolor=lightblue];');
    end;
    WriteLn(f, '  }');
    WriteLn(f, '');
    
    // Generar encabezados de filas (destinatarios) y celdas de la matriz
    WriteLn(f, '  // Filas de la matriz (Destinatarios que recibieron correos)');
    for i := 0 to numDestinatarios - 1 do
    begin
      WriteLn(f, '  subgraph cluster_fila', i, ' {');
      WriteLn(f, '    label="', LimpiarTextoGraphviz(destinatarios[i]), '";');
      WriteLn(f, '    style=filled;');
      WriteLn(f, '    fillcolor=lightgreen;');
      WriteLn(f, '    rank=same;');
      
      // Encabezado de fila
      WriteLn(f, '    dest', i, ' [label="', LimpiarTextoGraphviz(destinatarios[i]), '", fillcolor=lightgreen];');
      
      // Celdas de la matriz para esta fila
      for j := 0 to numRemitentes - 1 do
      begin
        if matriz[i][j] > 0 then
        begin
          WriteLn(f, '    celda', i, '_', j, ' [label="', matriz[i][j], 
                  '", fillcolor=orange, style="filled,bold"];');
        end
        else
        begin
          WriteLn(f, '    celda', i, '_', j, ' [label="0", fillcolor=white];');
        end;
      end;
      WriteLn(f, '  }');
      WriteLn(f, '');
    end;
    
    // Conexiones para formar la estructura de matriz
    WriteLn(f, '  // Conexiones de estructura');
    WriteLn(f, '  titulo -> dest0;');
    
    // Conexiones horizontales (dentro de cada fila)
    for i := 0 to numDestinatarios - 1 do
    begin
      WriteLn(f, '  dest', i, ' -> celda', i, '_0 [style=invisible];');
      for j := 0 to numRemitentes - 2 do
      begin
        WriteLn(f, '  celda', i, '_', j, ' -> celda', i, '_', j + 1, ' [style=invisible];');
      end;
    end;
    
    // Conexiones verticales (entre filas)
    for i := 0 to numDestinatarios - 2 do
    begin
      WriteLn(f, '  dest', i, ' -> dest', i + 1, ' [style=invisible];');
    end;
    
    WriteLn(f, '');
    WriteLn(f, '  // Leyenda');
    WriteLn(f, '  leyenda [label="Números indican cantidad de\\ncorreos ENVIADOS entre usuarios", shape=box, style=filled, fillcolor=lightyellow];');
    WriteLn(f, '  titulo -> leyenda [style=dashed];');
  end;
  
  WriteLn(f, '}');
  CloseFile(f);
  WriteLn('📊 Gráfico de matriz dispersa (correos enviados) generado: ', archivo);
end;

procedure GenerarTodosLosGraficos;
var
  carpeta: String;
  comando: String;
  archivos: array[0..5] of String;
  nombres: array[0..5] of String;
  i: Integer;
  exito: Boolean;
begin
  carpeta := '../graficos/';
  
  // Crear carpeta si no existe
  if not DirectoryExists(carpeta) then
    ForceDirectories(carpeta);
    
  WriteLn('🎨 Generando todos los gráficos Graphviz...');
  WriteLn('📁 Carpeta: ', carpeta);
  WriteLn('');
  
  // Generar archivos .dot
  GenerarGraficoUsuarios(carpeta + 'usuarios.dot');
  GenerarGraficoCorreos(carpeta + 'correos.dot');
  GenerarGraficoContactos(carpeta + 'contactos.dot');
  GenerarGraficoCola(carpeta + 'cola.dot');
  GenerarGraficoPapelera(carpeta + 'papelera.dot');
  GenerarGraficoMatrizDispersa(carpeta + 'matriz.dot');
  
  WriteLn('');
  
  // Verificar si Graphviz está disponible
  if not ComprobarGraphviz then
  begin
    WriteLn('');
    WriteLn('⚠️ No se pueden generar imágenes PNG automáticamente');
    WriteLn('📄 Archivos .dot generados exitosamente en: ', carpeta);
    WriteLn('');
    WriteLn('💡 Una vez instalado Graphviz, puedes generar imágenes manualmente con:');
    WriteLn('   cd ', carpeta);
    WriteLn('   dot -Tpng usuarios.dot -o usuarios.png');
    WriteLn('   dot -Tpng correos.dot -o correos.png');
    WriteLn('   dot -Tpng contactos.dot -o contactos.png');
    WriteLn('   dot -Tpng cola.dot -o cola.png');
    WriteLn('   dot -Tpng papelera.dot -o papelera.png');
    WriteLn('   dot -Tpng matriz.dot -o matriz.png');
    Exit;
  end;
  
  WriteLn('🖼️ Generando imágenes PNG...');
  
  // Configurar arrays con nombres de archivos
  archivos[0] := 'usuarios';
  archivos[1] := 'correos';
  archivos[2] := 'contactos';
  archivos[3] := 'cola';
  archivos[4] := 'papelera';
  archivos[5] := 'matriz';
  
  nombres[0] := 'Lista Simple - Usuarios';
  nombres[1] := 'Lista Doble - Correos';
  nombres[2] := 'Lista Circular - Contactos';
  nombres[3] := 'Cola - Programados';
  nombres[4] := 'Pila - Papelera';
  nombres[5] := 'Matriz Dispersa - Relaciones';
  
  // Generar archivos PNG
  for i := 0 to 5 do
  begin
    Write('  📊 Generando ', nombres[i], '... ');
    
    {$IFDEF WINDOWS}
    comando := 'dot -Tpng "' + carpeta + archivos[i] + '.dot" -o "' + carpeta + archivos[i] + '.png"';
    {$ELSE}
    comando := 'dot -Tpng "' + carpeta + archivos[i] + '.dot" -o "' + carpeta + archivos[i] + '.png"';
    {$ENDIF}
    
    exito := EjecutarComando(comando);
    
    if exito then
      WriteLn('✅')
    else
      WriteLn('❌');
  end;
  
  WriteLn('');
  WriteLn('🎯 Proceso completado!');
  WriteLn('📁 Archivos disponibles en: ', carpeta);
  WriteLn('');
  WriteLn('📄 Archivos .dot (código fuente):');
  WriteLn('   - usuarios.dot');
  WriteLn('   - correos.dot');
  WriteLn('   - contactos.dot');
  WriteLn('   - cola.dot');
  WriteLn('   - papelera.dot');
  WriteLn('   - matriz.dot');
  WriteLn('');
  WriteLn('🖼️ Archivos .png (imágenes):');
  WriteLn('   - usuarios.png');
  WriteLn('   - correos.png');
  WriteLn('   - contactos.png');
  WriteLn('   - cola.png');
  WriteLn('   - papelera.png');
  WriteLn('   - matriz.png');
end;

end.
