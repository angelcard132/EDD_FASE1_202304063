unit bandeja_entrada;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader, reports, pila2, eliminar, blockchain;

procedure MostrarBandejaEntrada(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila; var blockchainMail: TBlockchain);

implementation

type
  PCorreoRecibido = ^TCorreoRecibido;
  TCorreoRecibido = record
    id: Integer;
    remitente: String;
    asunto: String;
    mensaje: String;
    estado: String;
    siguiente: PCorreoRecibido;
  end;

var
  GEmailUsuario: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  GPapelera: ^TPila = nil;
  GBlockchain: ^TBlockchain = nil; // Add blockchain reference
  
  BandejaWindow: PGtkWidget = nil;
  ListaCorreos: PGtkWidget = nil;
  TextViewDetalle: PGtkWidget = nil;
  LabelInfo: PGtkWidget = nil;
  RespuestaWindow: PGtkWidget = nil;
  
  // Variables para el formulario de respuesta
  EntryRespuestaPara: PGtkWidget = nil;
  EntryRespuestaAsunto: PGtkWidget = nil;
  TextViewRespuestaMensaje: PGtkWidget = nil;
  
  CorreoSeleccionado: Integer = 0;
  CorreoSeleccionadoID: Integer = 0; // Agregar esta variable que falta

{ === FUNCIONES AUXILIARES === }

function GenerarNuevoIDCorreo(): Integer;
begin
  Result := Trunc(Now * 86400) mod 100000;
end;

procedure MostrarMensaje(const titulo, mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_window_set_title(GTK_WINDOW(dialog), PChar(titulo));
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

function ObtenerTextoTextView(textView: PGtkWidget): String;
var
  buffer: PGtkTextBuffer;
  startIter, endIter: TGtkTextIter;
  texto: PChar;
begin
  buffer := gtk_text_view_get_buffer(PGtkTextView(textView));
  gtk_text_buffer_get_start_iter(buffer, @startIter);
  gtk_text_buffer_get_end_iter(buffer, @endIter);
  texto := gtk_text_buffer_get_text(buffer, @startIter, @endIter, False);
  Result := StrPas(texto);
  g_free(texto);
end;

function SanearUTF8(const s: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if (Ord(c) >= 32) and (Ord(c) <= 126) then  // Solo ASCII imprimible básico
      Result := Result + c
    else
      Result := Result + '?';  // Reemplazar cualquier otro carácter
  end;
end;

// Función más robusta para limpiar texto UTF-8
function LimpiarTextoParaGTK(const texto: String): String;
var
  i: Integer;
  resultado: String;
  c: Char;
begin
  resultado := '';
  for i := 1 to Length(texto) do
  begin
    c := texto[i];
    // Solo permitir caracteres ASCII básicos y algunos caracteres seguros
    if (Ord(c) >= 32) and (Ord(c) <= 126) then
      resultado := resultado + c
    else if (c = #13) or (c = #10) then
      resultado := resultado + c  // Mantener saltos de línea
    else
      resultado := resultado + '?';  // Reemplazar caracteres problemáticos
  end;
  Result := resultado;
end;

procedure LiberarListaCorreos(var lista: PCorreoRecibido);
var
  actual, temp: PCorreoRecibido;
begin
  actual := lista;
  while actual <> nil do
  begin
    temp := actual^.siguiente;
    Dispose(actual);
    actual := temp;
  end;
  lista := nil;
end;

procedure AgregarCorreoALista(var lista: PCorreoRecibido; id: Integer; const remitente, asunto, mensaje, estado: String);
var
  nuevo: PCorreoRecibido;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.asunto := asunto;
  nuevo^.mensaje := mensaje;
  nuevo^.estado := estado;
  nuevo^.siguiente := lista;
  lista := nuevo;
end;

// Normaliza el email para comparación robusta:
// - a minúsculas
// - reemplaza guiones raros por '-'
// - elimina espacios y caracteres no ASCII
// - deja solo [a-z0-9@._-+] (se conserva '+')
function NormalizarEmail(const s: String): String;
var
  i: Integer;
  c: Char;
  lower: String;
begin
  lower := LowerCase(s);
  Result := '';
  for i := 1 to Length(lower) do
  begin
    c := lower[i];
    if (c = #$E2) or (c = #$C2) then
      Continue;
    if (c = '–') or (c = '—') or (c = '−') or (c = '‑') then
      c := '-';
    if ((c >= 'a') and (c <= 'z')) or ((c >= '0') and (c <= '9')) or
       (c = '@') or (c = '.') or (c = '_') or (c = '-') or (c = '+') then
      Result := Result + c
    else
      ; // ignorar
  end;
end;

// Extrae el email de un token "Nombre <user@dom.com>" o simple y lo normaliza
function ExtraerEmailDesdeToken(const token: String): String;
var
  tmp: String;
  p1, p2: SizeInt;
begin
  tmp := Trim(token);
  p1 := Pos('<', tmp);
  p2 := LastDelimiter('>', tmp);
  if (p1 > 0) and (p2 > p1) then
    tmp := Copy(tmp, p1 + 1, p2 - p1 - 1);
  Result := NormalizarEmail(tmp);
end;

// Divide email en local y dominio ya normalizados
procedure SplitLocalDomain(const email: String; out localPart, domain: String);
var
  p: SizeInt;
  e: String;
begin
  e := NormalizarEmail(email);
  p := Pos('@', e);
  if p > 0 then
  begin
    localPart := Copy(e, 1, p - 1);
    domain := Copy(e, p + 1, Length(e) - p);
  end
  else
  begin
    localPart := e;
    domain := '';
  end;
end;

// Aplica reglas de alias comunes de Gmail: ignorar '.' y '+sufijo' en la parte local
function GmailNormalizeLocal(const s: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if c = '+' then Break; // ignora sufijo desde '+'
    if c <> '.' then
      Result := Result + c; // ignora puntos
  end;
end;

// Comparación flexible de emails: exacta tras normalizar;
// si no coincide y el dominio es gmail/googlemail, aplica alias.
function EmailsCoincidenFlex(const a, b: String): Boolean;
var
  an, bn: String;
  al, ad, bl, bd: String;
begin
  an := NormalizarEmail(a);
  bn := NormalizarEmail(b);
  if an = bn then Exit(True);

  SplitLocalDomain(an, al, ad);
  SplitLocalDomain(bn, bl, bd);

  if (ad = bd) and ((ad = 'gmail.com') or (ad = 'googlemail.com')) then
    Exit(GmailNormalizeLocal(al) = GmailNormalizeLocal(bl));

  Result := False;
end;

// Helper: ¿carácter válido en un email?
function EsCharEmailValido(c: Char): Boolean; inline;
begin
  Result := ((c >= 'a') and (c <= 'z')) or
            ((c >= 'A') and (c <= 'Z')) or
            ((c >= '0') and (c <= '9')) or
            (c in ['@', '.', '_', '-', '+']);
end;

// Revisa si el campo destinatario contiene el email del usuario.
// Escanea la cadena y extrae tokens que parezcan emails (con '@'), probando con EmailsCoincidenFlex.
// Si no encuentra tokens, hace un respaldo buscando el email normalizado como substring.
function ContieneDestinatario(const emailCampo, emailBuscado: String): Boolean;
var
  emailNormalizado, buscadoNormalizado: String;
begin
  // Normalizar ambos emails para comparación
  emailNormalizado := LowerCase(Trim(emailCampo));
  buscadoNormalizado := LowerCase(Trim(emailBuscado));
  
  // Comparación exacta primero
  if emailNormalizado = buscadoNormalizado then
  begin
    Result := True;
    Exit;
  end;
  
  // Buscar como substring (para casos de múltiples destinatarios)
  Result := Pos(buscadoNormalizado, emailNormalizado) > 0;
end;

procedure OnSeleccionarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
var
  selection: PGtkTreeSelection;
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  idStr, remitente, asunto, estado: PChar;
  remitenteStr, asuntoStr, estadoStr: String;
  buffer: PGtkTextBuffer;
  correoID: Integer;
  actual: cola2.PCorreo;
  mensaje: String;
  textoDetalle: String;
  encontrado: Boolean;
  estadoAnterior: String;
  store: PGtkListStore;
begin
  WriteLn('DEBUG - OnSeleccionarCorreo iniciado');

  if ListaCorreos = nil then 
  begin
    WriteLn('DEBUG - ListaCorreos es nil');
    Exit;
  end;

  selection := gtk_tree_view_get_selection(PGtkTreeView(ListaCorreos));
  if selection = nil then 
  begin
    WriteLn('DEBUG - selection es nil');
    Exit;
  end;

  if gtk_tree_selection_get_selected(selection, @model, @iter) then
  begin
    // Inicializar punteros
    idStr := nil;
    remitente := nil;
    asunto := nil;
    estado := nil;
    
    // Obtener datos de la fila seleccionada
    gtk_tree_model_get(model, @iter, 
                       0, @idStr,       // Columna 0: ID
                       1, @remitente,   // Columna 1: De (remitente)  
                       2, @asunto,      // Columna 2: Asunto
                       3, @estado,      // Columna 3: Estado
                       -1);

    WriteLn('DEBUG - Datos obtenidos del modelo GTK');
    
    // Convertir datos de forma segura
    remitenteStr := '';
    asuntoStr := '';
    estadoStr := '';
    correoID := 0;
    
    if idStr <> nil then
    begin
      correoID := StrToIntDef(StrPas(idStr), 0);
      WriteLn('DEBUG - ID convertido: ', correoID);
      g_free(idStr);
    end;
    
    if remitente <> nil then
    begin
      remitenteStr := StrPas(remitente);
      WriteLn('DEBUG - Remitente: "', remitenteStr, '"');
      g_free(remitente);
    end;
    
    if asunto <> nil then
    begin
      asuntoStr := StrPas(asunto);
      WriteLn('DEBUG - Asunto: "', asuntoStr, '"');
      g_free(asunto);
    end;
    
    if estado <> nil then
    begin
      estadoStr := StrPas(estado);
      WriteLn('DEBUG - Estado actual en interfaz: "', estadoStr, '"');
      g_free(estado);
    end;

    if correoID <> 0 then
    begin
      CorreoSeleccionadoID := correoID; // Guardar ID para otras operaciones
      WriteLn('DEBUG - Buscando mensaje completo para ID: ', correoID);

      // Obtener estado actual del correo
      estadoAnterior := ObtenerEstadoCorreo(correoID);
      WriteLn('DEBUG - Estado anterior del correo: "', estadoAnterior, '"');

      // Si el correo está "No Leído", marcarlo como "Leído"
      if (estadoAnterior = 'NL') or (estadoStr = 'No Leído') then
      begin
        EstablecerEstadoCorreo(correoID, 'L');
        WriteLn('📖 Correo marcado como LEÍDO: ID ', correoID);
        
        // Actualizar la fila en la interfaz inmediatamente
        store := PGtkListStore(model);
        gtk_list_store_set(store, @iter, 3, PChar('Leído'), -1);
        WriteLn('✅ Estado actualizado en interfaz: No Leído -> Leído');
      end;

      // Buscar el mensaje completo en la cola
      mensaje := '';
      encontrado := False;
      
      if GProgramados <> nil then
      begin
        actual := GProgramados^.frente;
        WriteLn('DEBUG - Iniciando búsqueda en cola...');
        
        while actual <> nil do
        begin
          WriteLn('DEBUG - Revisando correo en cola ID: ', actual^.id);
          if actual^.id = correoID then
          begin
            mensaje := String(actual^.mensaje);
            encontrado := True;
            WriteLn('DEBUG - ¡Mensaje encontrado! Longitud: ', Length(mensaje));
            WriteLn('DEBUG - Primeros 100 chars: "', Copy(mensaje, 1, 100), '"');
            Break;
          end;
          actual := actual^.siguiente;
        end;
      end
      else
        WriteLn('DEBUG - ERROR: GProgramados es nil');

      if not encontrado then
      begin
        WriteLn('DEBUG - Mensaje no encontrado en cola, usando placeholder');
        mensaje := 'Mensaje no disponible';
      end;

      // Limpiar todos los textos antes de construir el detalle
      remitenteStr := LimpiarTextoParaGTK(remitenteStr);
      asuntoStr := LimpiarTextoParaGTK(asuntoStr);
      mensaje := LimpiarTextoParaGTK(mensaje);

      // Construir texto de detalle con estado actualizado
      textoDetalle := 'DETALLE DEL CORREO' + #13#10 +
                      '==================' + #13#10 + #13#10 +
                      'ID: ' + IntToStr(correoID) + #13#10 +
                      'De: ' + remitenteStr + #13#10 +
                      'Para: ' + LimpiarTextoParaGTK(GEmailUsuario) + #13#10 +
                      'Estado: Leído' + #13#10 + #13#10 +  // Siempre mostrar como "Leído" después de ver
                      'ASUNTO:' + #13#10 +
                      asuntoStr + #13#10 + #13#10 +
                      'MENSAJE:' + #13#10 +
                      '--------' + #13#10 +
                      mensaje;

      WriteLn('DEBUG - Texto detalle construido, longitud: ', Length(textoDetalle));
      WriteLn('DEBUG - Primeros 200 chars limpios: "', Copy(textoDetalle, 1, 200), '"');

      // Mostrar en TextView de forma segura
      if TextViewDetalle <> nil then
      begin
        buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
        if buffer <> nil then
        begin
          try
            // Limpiar buffer primero
            gtk_text_buffer_set_text(buffer, '', 0);
            
            // Establecer texto limpio
            gtk_text_buffer_set_text(buffer, PChar(textoDetalle), Length(textoDetalle));
            WriteLn('DEBUG - Texto establecido en buffer exitosamente sin errores UTF-8');
            
            // Forzar actualización de la interfaz
            gtk_widget_queue_draw(TextViewDetalle);
            gtk_widget_queue_draw(ListaCorreos); // También actualizar la lista
            
            // Procesar eventos pendientes
            while gtk_events_pending() > 0 do
              gtk_main_iteration();
              
            WriteLn('DEBUG - Interfaz actualizada correctamente');
          except
            on E: Exception do
            begin
              WriteLn('DEBUG - Error al establecer texto: ', E.Message);
              gtk_text_buffer_set_text(buffer, 'Error mostrando correo - caracteres especiales', -1);
            end;
          end;
        end
        else
          WriteLn('DEBUG - ERROR: buffer es nil');
      end
      else
        WriteLn('DEBUG - ERROR: TextViewDetalle es nil');
        
      WriteLn('DEBUG - Proceso completado para correo ID: ', correoID);
    end
    else
      WriteLn('DEBUG - ID inválido o 0');
  end
  else
  begin
    WriteLn('DEBUG - No hay selección válida');
    CorreoSeleccionadoID := 0; // Reset selección
    if TextViewDetalle <> nil then
    begin
      buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
      if buffer <> nil then
        gtk_text_buffer_set_text(buffer, 'Selecciona un correo para ver detalles', -1);
    end;
  end;
end;

function ObtenerCorreosRecibidos(const emailDestino: String): PCorreoRecibido;
var
  lista: PCorreoRecibido;
  actual: cola2.PCorreo;
  estadoTexto: String;
  emailActual: String;
  contador: Integer;
  emailDestinoNorm: String;
begin
  lista := nil;
  contador := 0;

  emailDestinoNorm := NormalizarEmail(emailDestino);
  WriteLn('🔍 BUSCANDO CORREOS PARA: "', emailDestino, '"');
  WriteLn('📧 Email normalizado: "', emailDestinoNorm, '"');

  if GProgramados = nil then
  begin
    WriteLn('❌ ERROR: GProgramados es nil');
    Result := lista;
    Exit;
  end;

  if GProgramados^.frente = nil then
  begin
    WriteLn('📭 Cola está vacía - no hay correos');
    Result := lista;
    Exit;
  end;

  WriteLn('📬 Iniciando búsqueda en cola de correos...');
  actual := GProgramados^.frente;
  while actual <> nil do
  begin
    emailActual := String(actual^.destinatario);

    WriteLn('🔎 Revisando correo ID ', actual^.id);
    WriteLn('   📤 De: "', String(actual^.remitente), '"');
    WriteLn('   📥 Para: "', emailActual, '"');
    WriteLn('   📋 Asunto: "', String(actual^.asunto), '"');
    WriteLn('   💬 Mensaje: "', Copy(String(actual^.mensaje), 1, 50), '..."');
    WriteLn('   🔍 Comparando: "', emailActual, '" vs "', emailDestinoNorm, '"');

    // Comparación robusta - mejorada
    if ContieneDestinatario(emailActual, emailDestinoNorm) then
    begin
      WriteLn('   ✅ ¡COINCIDENCIA! Correo para este usuario');

      // Obtener estado correctamente
      estadoTexto := ObtenerEstadoCorreo(actual^.id);
      WriteLn('   📊 Estado crudo obtenido: "', estadoTexto, '"');
      
      if estadoTexto = 'L' then
        estadoTexto := 'Leído'
      else
        estadoTexto := 'No Leído';
        
      WriteLn('   📊 Estado final: "', estadoTexto, '"');

      AgregarCorreoALista(
        lista,
        actual^.id,
        String(actual^.remitente),
        String(actual^.asunto),
        String(actual^.mensaje),
        estadoTexto
      );

      Inc(contador);
      WriteLn('   📊 Correo #', contador, ' agregado a la bandeja con mensaje completo');
    end
    else
      WriteLn('   ⏭️ No coincide, continuando...');

    actual := actual^.siguiente;
  end;

  WriteLn('📊 RESUMEN DE BÚSQUEDA:');
  WriteLn('   ✉️ Total correos encontrados: ', contador);
  WriteLn('   📧 Usuario: ', emailDestino);
  Result := lista;
end;

procedure CargarCorreosEnLista(lista: PCorreoRecibido);
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actual: PCorreoRecibido;
  idStr: String;
  contador: Integer;
begin
  if ListaCorreos = nil then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaCorreos)));
  if store = nil then Exit;
  
  gtk_list_store_clear(store);
  
  actual := lista;
  contador := 0;
  
  WriteLn('📋 Cargando correos en interfaz gráfica...');
  while actual <> nil do
  begin
    idStr := IntToStr(actual^.id);
    
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 
                       0, PChar(SanearUTF8(idStr)),
                       1, PChar(SanearUTF8(actual^.remitente)),
                       2, PChar(SanearUTF8(actual^.asunto)),
                       3, PChar(SanearUTF8(actual^.estado)),
                       -1);
    
    Inc(contador);
    WriteLn('✅ Correo agregado a lista visual: ID ', actual^.id, ' - "', actual^.asunto, '"');
    actual := actual^.siguiente;
  end;
  
  WriteLn('📊 Total correos mostrados en interfaz: ', contador);
end;

procedure OnAgregarAFavoritos(widget: PGtkWidget; data: gpointer); cdecl;
var
  actual: cola2.PCorreo;
  correoFav: TCorreoB;
  encontrado: Boolean;
begin
  if CorreoSeleccionadoID <= 0 then
  begin
    WriteLn('⚠️ Selecciona un correo para agregar a favoritos');
    Exit;
  end;
  
  // Buscar el correo en la cola de programados
  encontrado := False;
  actual := GProgramados^.frente;
  while actual <> nil do
  begin
    if actual^.id = CorreoSeleccionadoID then
    begin
      // Verificar si ya existe en favoritos
      if Buscar(GFavoritos^, CorreoSeleccionadoID) <> nil then
      begin
        WriteLn('⚠️ Este correo ya está en favoritos');
        Exit;
      end;
      
      // Crear registro para árbol B
      correoFav.id := actual^.id;
      correoFav.remitente := String(actual^.remitente);
      correoFav.destinatario := String(actual^.destinatario);
      correoFav.asunto := String(actual^.asunto);
      correoFav.mensaje := String(actual^.mensaje);
      
      // Insertar en árbol B
      Insertar(GFavoritos^, correoFav);
      
      WriteLn('⭐ Correo agregado a favoritos ID: ', CorreoSeleccionadoID);
      WriteLn('  - Asunto: ', correoFav.asunto);
      encontrado := True;
      Break;
    end;
    actual := actual^.siguiente;
  end;
  
  if not encontrado then
    WriteLn('❌ No se pudo encontrar el correo seleccionado');
end;

procedure OnActualizarBandeja(widget: PGtkWidget; data: gpointer); cdecl;
var
  lista: PCorreoRecibido;
begin
  lista := ObtenerCorreosRecibidos(GEmailUsuario);
  CargarCorreosEnLista(lista);
  LiberarListaCorreos(lista);
  
  // Limpiar detalle
  if TextViewDetalle <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 'Selecciona un correo para ver detalles', -1);
end;

procedure OnCerrarBandeja(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(BandejaWindow) then
    gtk_widget_destroy(BandejaWindow);
end;

procedure OnGenerarGrafica(widget: PGtkWidget; data: gpointer); cdecl;
var
  rutaDir, rutaDot, rutaPng: String;
begin
  // Guardar DOT en carpeta graficos/usuarios
  rutaDir := ExtractFileDir(ExtractFileDir(ParamStr(0))) + '/graficos/usuarios';
  if not DirectoryExists(rutaDir) then
    CreateDir(rutaDir);

  rutaDot := rutaDir + '/bandeja_usuario.dot';
  rutaPng := rutaDir + '/bandeja_usuario.png';

  GenerarGraficoBandeja(GEmailUsuario, GProgramados^, rutaDot);
  WriteLn('🗺️ DOT generado en: ', rutaDot);

  // Intentar generar PNG con dot si está disponible
  // Intentar generar PNG con dot si está instalado
  if ExecuteProcess('/bin/sh', ['-c', 'command -v dot >/dev/null 2>&1'], []) = 0 then
  begin
    if ExecuteProcess('/bin/sh', ['-c', 'dot -Tpng ' + rutaDot + ' -o ' + rutaPng], []) = 0 then
      WriteLn('🖼️ PNG generado en: ', rutaPng)
    else
      WriteLn('⚠️ No se pudo generar PNG con dot');
  end
  else
    WriteLn('ℹ️ Graphviz no está instalado; se dejó el .dot');
end;

function OnDeleteEventBandeja(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando bandeja de entrada...');
  if Assigned(BandejaWindow) then
    gtk_widget_destroy(BandejaWindow);
  Result := True; // Prevenir cierre de aplicación
end;

procedure MostrarNotificacion(const mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_window_set_title(GTK_WINDOW(dialog), 'Notificación');
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

procedure OnEliminarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
var
  actual, anterior: cola2.PCorreo;
  correoEncontrado: Boolean;
  remitente, destinatario, asunto, mensaje: String;
begin
  if CorreoSeleccionadoID <= 0 then
  begin
    MostrarNotificacion('⚠️ Selecciona un correo para eliminar', GTK_MESSAGE_WARNING);
    Exit;
  end;
  
  // Buscar el correo en la cola de programados
  correoEncontrado := False;
  anterior := nil;
  actual := GProgramados^.frente;
  
  while actual <> nil do
  begin
    if actual^.id = CorreoSeleccionadoID then
    begin
      // Guardar datos antes de eliminar
      remitente := String(actual^.remitente);
      destinatario := String(actual^.destinatario);
      asunto := String(actual^.asunto);
      mensaje := String(actual^.mensaje);
      
      // Eliminar de la cola
      if anterior = nil then
        GProgramados^.frente := actual^.siguiente
      else
        anterior^.siguiente := actual^.siguiente;
      
      if actual = GProgramados^.final then
        GProgramados^.final := anterior;
      
      // Mover a papelera
      EliminarCorreoDeBandeja(actual^.id, remitente, destinatario, asunto, mensaje, GPapelera^);
      
      Dispose(actual);
      correoEncontrado := True;
      Break;
    end;
    anterior := actual;
    actual := actual^.siguiente;
  end;
  
  if correoEncontrado then
  begin
    MostrarNotificacion('✅ Correo eliminado exitosamente y movido a papelera', GTK_MESSAGE_INFO);
    CorreoSeleccionadoID := 0; // Reset selección
    
    // Actualizar bandeja automáticamente
    OnActualizarBandeja(nil, nil);
  end
  else
    MostrarNotificacion('❌ No se pudo encontrar el correo seleccionado', GTK_MESSAGE_ERROR);
end;

function ValidarDestinatarioExiste(const emailDestinatario: String): Boolean;
var
  actual: PUsuario;
begin
  Result := False;
  
  if GUsuarios = nil then Exit;
  
  actual := GUsuarios^.cabeza;
  while actual <> nil do
  begin
    if LowerCase(String(actual^.email)) = LowerCase(emailDestinatario) then
    begin
      Result := True;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

function ObtenerNombreContactoPorEmail(const emailDestinatario: String): String;
var
  actual: PUsuario;
begin
  Result := emailDestinatario; // Por defecto retornar el email
  
  if GUsuarios = nil then Exit;
  
  actual := GUsuarios^.cabeza;
  while actual <> nil do
  begin
    if LowerCase(String(actual^.email)) = LowerCase(emailDestinatario) then
    begin
      Result := String(actual^.nombre);
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

procedure OnEnviarRespuesta(widget: PGtkWidget; data: gpointer); cdecl;
var
  para, asunto, mensaje: String;
  nuevoID: Integer;
  nombreContacto: String;
begin
  para := StrPas(gtk_entry_get_text(PGtkEntry(EntryRespuestaPara)));
  asunto := StrPas(gtk_entry_get_text(PGtkEntry(EntryRespuestaAsunto)));
  mensaje := ObtenerTextoTextView(TextViewRespuestaMensaje);

  // Validaciones básicas
  if (para = '') or (asunto = '') or (mensaje = '') then
  begin
    MostrarMensaje('Error de Validación', 'Todos los campos son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if Pos('@', para) = 0 then
  begin
    MostrarMensaje('Error de Validación', 'El email del destinatario debe contener @.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // NUEVA VALIDACIÓN: Verificar que el destinatario existe
  if not ValidarDestinatarioExiste(para) then
  begin
    nombreContacto := para;
    MostrarMensaje('Contacto No Encontrado', 
      'El destinatario "' + nombreContacto + '" no existe en tu lista de contactos.' + LineEnding + LineEnding +
      'Para enviar correos debes:' + LineEnding +
      '1. Agregar el contacto desde "👥 Agregar Contacto", o' + LineEnding +
      '2. Pedirle al administrador que cargue masivamente a este usuario' + LineEnding + LineEnding +
      'Solo puedes enviar correos a contactos registrados en el sistema.', 
      GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Si el destinatario existe, obtener su nombre para mostrar confirmación
  nombreContacto := ObtenerNombreContactoPorEmail(para);

  // Generar ID y enviar correo
  nuevoID := GenerarNuevoIDCorreo();
  Encolar(GProgramados^, nuevoID, GEmailUsuario, para, asunto, mensaje);
  EstablecerEstadoCorreo(nuevoID, 'NL'); // Estado: No Leído
  
  // NUEVO: Registrar en blockchain
  if GBlockchain <> nil then
  begin
    WriteLn('🔗 Registrando correo en blockchain...');
    RegistrarCorreoEnBlockchain(GBlockchain^, nuevoID, GEmailUsuario, para, asunto, mensaje);
  end;
  
  WriteLn('✅ Respuesta enviada exitosamente a: ', para);
  
  MostrarMensaje('Respuesta Enviada', 
    'La respuesta ha sido enviada exitosamente.' + LineEnding + LineEnding +
    'Para: ' + nombreContacto + ' (' + para + ')' + LineEnding +
    'Asunto: ' + asunto + LineEnding + LineEnding +
    'El correo aparecerá en la bandeja del destinatario y se ha registrado en la blockchain.', 
    GTK_MESSAGE_INFO);
  
  // Cerrar ventana de respuesta
  if Assigned(RespuestaWindow) then
    gtk_widget_destroy(RespuestaWindow);
end;

procedure MostrarBandejaEntrada(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila; var blockchainMail: TBlockchain);
var
  hpaned, vboxIzq, vboxDer, scrolledLista, scrolledDetalle: PGtkWidget;
  lblTitulo, lblDetalle: PGtkWidget;
  btnActualizar, btnCerrar, btnGrafica, btnFavoritos, btnEliminar, btnBox: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  lista: PCorreoRecibido;
begin
  // Guardar referencias globales
  GEmailUsuario := NormalizarEmail(emailUsuario);
  GProgramados := @programados;
  GFavoritos := @favoritos;
  GPapelera := @papelera;
  GBlockchain := @blockchainMail; // Add blockchain reference
  CorreoSeleccionadoID := 0;

  // Si existe una ventana previa, destruirla
  if Assigned(BandejaWindow) then
    gtk_widget_destroy(BandejaWindow);

  BandejaWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(BandejaWindow), PChar('Bandeja de Entrada - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(BandejaWindow), 1000, 650);
  
  // Conectar delete-event para prevenir cierre de aplicación
  g_signal_connect(BandejaWindow, 'delete-event', G_CALLBACK(@OnDeleteEventBandeja), nil);

  // Panel dividido horizontalmente
  hpaned := gtk_hpaned_new();
  gtk_container_add(GTK_CONTAINER(BandejaWindow), hpaned);

  // Panel izquierdo - Lista de correos
  vboxIzq := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxIzq), 10);
  gtk_paned_add1(GTK_PANED(hpaned), vboxIzq);

  lblTitulo := gtk_label_new('Correos Recibidos');
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblTitulo, False, False, 0);

  // Lista de correos
  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxIzq), scrolledLista, True, True, 0);

  // Crear modelo y vista - solo 4 columnas
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaCorreos := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaCorreos);

  // Columnas
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 40);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaCorreos), column);

  column := gtk_tree_view_column_new_with_attributes('De', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 180);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaCorreos), column);

  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaCorreos), column);

  column := gtk_tree_view_column_new_with_attributes('Estado', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 120);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaCorreos), column);

  // Conectar selección - IMPORTANTE: una sola conexión
  g_signal_connect(gtk_tree_view_get_selection(PGtkTreeView(ListaCorreos)), 
                   'changed', G_CALLBACK(@OnSeleccionarCorreo), nil);

  // Botones de acción
  btnBox := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox, False, False, 0);

  btnActualizar := gtk_button_new_with_label('🔄 Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarBandeja), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnActualizar, True, True, 0);

  btnFavoritos := gtk_button_new_with_label('⭐ A Favoritos');
  g_signal_connect(btnFavoritos, 'clicked', G_CALLBACK(@OnAgregarAFavoritos), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnFavoritos, True, True, 0);

  btnEliminar := gtk_button_new_with_label('🗑️ Eliminar');
  g_signal_connect(btnEliminar, 'clicked', G_CALLBACK(@OnEliminarCorreo), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnEliminar, True, True, 0);

  btnGrafica := gtk_button_new_with_label('📊 Gráfica');
  g_signal_connect(btnGrafica, 'clicked', G_CALLBACK(@OnGenerarGrafica), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnGrafica, True, True, 0);

  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarBandeja), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, True, True, 0);

  // Panel derecho - Detalle del correo
  vboxDer := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxDer), 10);
  gtk_paned_add2(GTK_PANED(hpaned), vboxDer);

  lblDetalle := gtk_label_new('Detalle del correo:');
  gtk_box_pack_start(GTK_BOX(vboxDer), lblDetalle, False, False, 0);

  scrolledDetalle := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDetalle), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxDer), scrolledDetalle, True, True, 0);

  TextViewDetalle := gtk_text_view_new();
  gtk_text_view_set_editable(PGtkTextView(TextViewDetalle), False);
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDetalle), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDetalle), TextViewDetalle);

  // Establecer mensaje inicial en TextView
  gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 
    'Selecciona un correo de la lista para ver sus detalles completos aquí.', -1);

  // Cargar correos iniciales
  WriteLn('DEBUG - Iniciando carga de correos para: ', emailUsuario, ' (normalizado: ', GEmailUsuario, ')');
  lista := ObtenerCorreosRecibidos(GEmailUsuario);
  CargarCorreosEnLista(lista);
  LiberarListaCorreos(lista);

  gtk_widget_show_all(BandejaWindow);
end;

end.
