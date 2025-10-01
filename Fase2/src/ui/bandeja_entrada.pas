unit bandeja_entrada;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader, reports;

procedure MostrarBandejaEntrada(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

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
  GProgramados: ^TCola = nil;
  GFavoritos: ^PNodoB = nil;
  
  BandejaWindow: PGtkWidget = nil;
  ListaCorreos: PGtkWidget = nil;
  TextViewDetalle: PGtkWidget = nil;
  
  CorreoSeleccionadoID: Integer = 0;

function SanearUTF8(const s: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if (Ord(c) >= 32) and (Ord(c) <> 127) then
      Result := Result + c
    else
      Result := Result + '?';
  end;
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
function ContieneDestinatario(const campoDestinatario, emailUsuario: String): Boolean;
var
  i: Integer;
  ch: Char;
  acc: String;
  tieneArroba: Boolean;
  objetivo, tokenNorm, campoNorm: String;
  tokensEncontrados: Integer;
begin
  objetivo := NormalizarEmail(emailUsuario);
  Result := False;
  acc := '';
  tieneArroba := False;
  tokensEncontrados := 0;

  WriteLn('DEBUG ContieneDestinatario - Campo destinatario: "', campoDestinatario, '"');
  WriteLn('DEBUG ContieneDestinatario - Email objetivo: "', objetivo, '"');

  // Escaneo carácter a carácter (robusto frente a JSON/ruido)
  for i := 1 to Length(campoDestinatario) do
  begin
    ch := campoDestinatario[i];
    if EsCharEmailValido(ch) then
    begin
      acc := acc + ch;
      if ch = '@' then
        tieneArroba := True;
    end
    else
    begin
      if tieneArroba and (acc <> '') then
      begin
        tokenNorm := NormalizarEmail(acc);
        Inc(tokensEncontrados);
        WriteLn('DEBUG ContieneDestinatario - Token #', tokensEncontrados, ': "', acc, '" -> normalizado: "', tokenNorm, '"');
        if (tokenNorm <> '') and EmailsCoincidenFlex(tokenNorm, objetivo) then
        begin
          WriteLn('DEBUG ContieneDestinatario - ¡COINCIDENCIA ENCONTRADA con token!');
          Exit(True);
        end;
      end;
      acc := '';
      tieneArroba := False;
    end;
  end;

  // Revisión del último token
  if tieneArroba and (acc <> '') then
  begin
    tokenNorm := NormalizarEmail(acc);
    Inc(tokensEncontrados);
    WriteLn('DEBUG ContieneDestinatario - Token final #', tokensEncontrados, ': "', acc, '" -> normalizado: "', tokenNorm, '"');
    if (tokenNorm <> '') and EmailsCoincidenFlex(tokenNorm, objetivo) then
    begin
      WriteLn('DEBUG ContieneDestinatario - ¡COINCIDENCIA ENCONTRADA con token final!');
      Exit(True);
    end;
  end;

  WriteLn('DEBUG ContieneDestinatario - Total tokens encontrados: ', tokensEncontrados);

  // Respaldo: búsqueda por substring en la cadena normalizada completa
  campoNorm := NormalizarEmail(campoDestinatario);
  WriteLn('DEBUG ContieneDestinatario - Campo normalizado completo: "', campoNorm, '"');
  if (campoNorm <> '') and (Pos(objetivo, campoNorm) > 0) then
  begin
    WriteLn('DEBUG ContieneDestinatario - ¡COINCIDENCIA ENCONTRADA por substring!');
    Exit(True);
  end;

  WriteLn('DEBUG ContieneDestinatario - No se encontró coincidencia');
end;

function ObtenerCorreosRecibidos(const emailDestino: String): PCorreoRecibido;
var
  lista: PCorreoRecibido;
  actual: PCorreo;
  estadoTexto: String;
  emailActual: String;
  contador: Integer;
  emailDestinoNorm: String;
begin
  lista := nil;
  contador := 0;

  emailDestinoNorm := NormalizarEmail(emailDestino);
  WriteLn('DEBUG - Buscando correos para: "', emailDestino, '"');
  WriteLn('DEBUG - Email normalizado: "', emailDestinoNorm, '"');

  if GProgramados = nil then
  begin
    WriteLn('ERROR - GProgramados es nil');
    Result := lista;
    Exit;
  end;

  if GProgramados^.frente = nil then
  begin
    WriteLn('DEBUG - Cola está vacía');
    Result := lista;
    Exit;
  end;

  actual := GProgramados^.frente;
  while actual <> nil do
  begin
    emailActual := String(actual^.destinatario);

    WriteLn('DEBUG - Revisando correo ID ', actual^.id);
    WriteLn('  - Destinatario original: "', emailActual, '"');
    WriteLn('  - Comparando con: "', emailDestinoNorm, '"');

    // Comparación robusta: múltiples destinatarios, wrappers y normalización
    if ContieneDestinatario(emailActual, emailDestinoNorm) then
    begin
      WriteLn('DEBUG - ¡COINCIDENCIA ENCONTRADA! Procesando correo...');

      if ObtenerEstadoCorreo(actual^.id) = 'L' then
        estadoTexto := 'Leido'
      else
        estadoTexto := 'No Leido';

      AgregarCorreoALista(
        lista,
        actual^.id,
        String(actual^.remitente),
        String(actual^.asunto),
        String(actual^.mensaje),
        estadoTexto
      );

      Inc(contador);
      WriteLn('DEBUG - Correo #', contador, ' agregado:');
      WriteLn('  - ID: ', actual^.id);
      WriteLn('  - Remitente: ', String(actual^.remitente));
      WriteLn('  - Asunto: ', String(actual^.asunto));
      WriteLn('  - Estado: ', estadoTexto);
    end
    else
      WriteLn('DEBUG - No coincide, continuando...');

    actual := actual^.siguiente;
  end;

  WriteLn('DEBUG - Total de correos encontrados: ', contador);
  Result := lista;
end;

procedure CargarCorreosEnLista(lista: PCorreoRecibido);
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actual: PCorreoRecibido;
  idStr: String;
begin
  if ListaCorreos = nil then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaCorreos)));
  if store = nil then Exit;
  
  gtk_list_store_clear(store);
  
  actual := lista;
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
    
    WriteLn('DEBUG - Correo agregado a lista: ', actual^.asunto);
    actual := actual^.siguiente;
  end;
end;

procedure OnAgregarAFavoritos(widget: PGtkWidget; data: gpointer); cdecl;
var
  actual: PCorreo;
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

procedure OnSeleccionarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
var
  selection: PGtkTreeSelection;
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  idStr, remitente, asunto, estado: PChar;
  remitenteStr, asuntoStr: String;
  buffer: PGtkTextBuffer;
  correoID: Integer;
  actual: PCorreo;
  mensaje: String;
  textoDetalle: String;
begin
  WriteLn('DEBUG - OnSeleccionarCorreo iniciado');

  if ListaCorreos = nil then Exit;

  selection := gtk_tree_view_get_selection(PGtkTreeView(ListaCorreos));
  if selection = nil then Exit;

  if gtk_tree_selection_get_selected(selection, @model, @iter) then
  begin
    idStr := nil; remitente := nil; asunto := nil; estado := nil;
    gtk_tree_model_get(model, @iter,
                       0, @idStr,
                       1, @remitente,
                       2, @asunto,
                       3, @estado,
                       -1);

    if idStr <> nil then
      correoID := StrToIntDef(StrPas(idStr), 0)
    else
      correoID := 0;

    if remitente <> nil then
      remitenteStr := StrPas(remitente)
    else
      remitenteStr := '';

    if asunto <> nil then
      asuntoStr := StrPas(asunto)
    else
      asuntoStr := '';

    if idStr <> nil then g_free(idStr);
    if remitente <> nil then g_free(remitente);
    if asunto <> nil then g_free(asunto);
    if estado <> nil then g_free(estado);

    if correoID <> 0 then
    begin
      CorreoSeleccionadoID := correoID; // Guardar ID para favoritos
      WriteLn('DEBUG - Correo seleccionado ID: ', correoID);

      // Buscar el mensaje completo en la cola
      mensaje := '';
      actual := GProgramados^.frente;
      while actual <> nil do
      begin
        if actual^.id = correoID then
        begin
          mensaje := String(actual^.mensaje);
          Break;
        end;
        actual := actual^.siguiente;
      end;

      // Actualizar estado a leído si aplica
      if ObtenerEstadoCorreo(correoID) = 'NL' then
      begin
        EstablecerEstadoCorreo(correoID, 'L');
        // Reflejar inmediatamente en la UI
        gtk_list_store_set(PGtkListStore(model), @iter, 3, PChar('Leido'), -1);
        WriteLn('DEBUG - Estado actualizado a LEIDO');
      end;

      // Crear texto de detalle simple
      textoDetalle := 'CORREO RECIBIDO' + #13#10 +
                      '==================' + #13#10 + #13#10 +
                      'ID: ' + IntToStr(correoID) + #13#10 +
                      'De: ' + SanearUTF8(remitenteStr) + #13#10 +
                      'Para: ' + SanearUTF8(GEmailUsuario) + #13#10 +
                      'Estado: Leido' + #13#10 + #13#10 +
                      'ASUNTO:' + #13#10 +
                      SanearUTF8(asuntoStr) + #13#10 + #13#10 +
                      'MENSAJE:' + #13#10 +
                      '--------' + #13#10 +
                      SanearUTF8(mensaje);

      // Mostrar en el panel de detalle
      if TextViewDetalle <> nil then
      begin
        buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
        if buffer <> nil then
        begin
          gtk_text_buffer_set_text(buffer, PChar(textoDetalle), -1);
          WriteLn('EXITO - Correo mostrado en detalle');
        end;
      end;
    end;
  end
  else
  begin
    CorreoSeleccionadoID := 0; // Reset selección
    WriteLn('DEBUG - No hay selección');
    if TextViewDetalle <> nil then
    begin
      buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
      if buffer <> nil then
        gtk_text_buffer_set_text(buffer, 'Selecciona un correo para ver detalles', -1);
    end;
  end;
end;

procedure OnActualizarBandeja(widget: PGtkWidget; data: gpointer); cdecl;
var
  lista: PCorreoRecibido;
begin
  lista := ObtenerCorreosRecibidos(GEmailUsuario);
  CargarCorreosEnLista(lista);
  LiberarListaCorreos(lista);
  
  // Limpiar detalle
  gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), '', -1);
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

procedure MostrarBandejaEntrada(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  hpaned, vboxIzq, vboxDer, scrolledLista, scrolledDetalle: PGtkWidget;
  lblTitulo, lblDetalle: PGtkWidget;
  btnActualizar, btnCerrar, btnGrafica, btnFavoritos, btnBox: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  lista: PCorreoRecibido;
begin
  // Guardar referencias globales
  GEmailUsuario := NormalizarEmail(emailUsuario);
  GProgramados := @programados;
  GFavoritos := @favoritos;
  CorreoSeleccionadoID := 0;

  // Si existe una ventana previa, destruirla
  if Assigned(BandejaWindow) then
    gtk_widget_destroy(BandejaWindow);

  BandejaWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(BandejaWindow), PChar('Bandeja de Entrada - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(BandejaWindow), 1000, 650);

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

  // Conectar selección
  g_signal_connect(gtk_tree_view_get_selection(PGtkTreeView(ListaCorreos)), 
                   'changed', G_CALLBACK(@OnSeleccionarCorreo), nil);

  // Botones - agregar botón de favoritos
  btnBox := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox, False, False, 0);

  btnActualizar := gtk_button_new_with_label('Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarBandeja), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnActualizar, True, True, 0);

  btnFavoritos := gtk_button_new_with_label('⭐ A Favoritos');
  g_signal_connect(btnFavoritos, 'clicked', G_CALLBACK(@OnAgregarAFavoritos), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnFavoritos, True, True, 0);

  btnGrafica := gtk_button_new_with_label('Generar gráfica');
  g_signal_connect(btnGrafica, 'clicked', G_CALLBACK(@OnGenerarGrafica), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnGrafica, True, True, 0);

  btnCerrar := gtk_button_new_with_label('Cerrar');
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

  // Cargar correos iniciales
  WriteLn('DEBUG - Iniciando carga de correos para: ', emailUsuario, ' (normalizado: ', GEmailUsuario, ')');
  lista := ObtenerCorreosRecibidos(GEmailUsuario);
  CargarCorreosEnLista(lista);
  LiberarListaCorreos(lista);

  gtk_widget_show_all(BandejaWindow);
end;

end.
