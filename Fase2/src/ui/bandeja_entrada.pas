unit bandeja_entrada;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader;

procedure MostrarBandejaEntrada(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

implementation

type
  PCorreoRecibido = ^TCorreoRecibido;
  TCorreoRecibido = record
    id: Integer;
    remitente: String;
    asunto: String;
    mensaje: String;
    estado: String; // NL = No Leído, L = Leído
    origen: String;
    siguiente: PCorreoRecibido;
  end;

var
  GEmailUsuario: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  
  BandejaWindow: PGtkWidget = nil;
  ListaCorreos: PGtkWidget = nil;
  TextViewDetalle: PGtkWidget = nil;

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
  nuevo^.origen := 'Cola';
  nuevo^.siguiente := lista;
  lista := nuevo;
end;

procedure BuscarCorreosEnCola(var lista: PCorreoRecibido; cola: TCola; const emailDestino: String);
var
  actual: PCorreo;
  estadoTexto, estadoCorreo: String;
begin
  WriteLn('DEBUG - Buscando en cola para: ', emailDestino);
  actual := cola.frente;
  while actual <> nil do
  begin
    WriteLn('DEBUG - Revisando correo en cola: "', actual^.destinatario, '" vs "', emailDestino, '"');
    
    // Comparación más robusta para emails
    if (Trim(LowerCase(actual^.destinatario)) = Trim(LowerCase(emailDestino))) then
    begin
      // Obtener estado desde la estructura separada
      estadoCorreo := ObtenerEstadoCorreo(actual^.id);
      
      // Determinar estado legible
      if estadoCorreo = 'NL' then
        estadoTexto := '📧 No Leído'
      else if estadoCorreo = 'L' then
        estadoTexto := '✅ Leído'
      else
        estadoTexto := '❓ ' + estadoCorreo;
        
      AgregarCorreoALista(lista, actual^.id, actual^.remitente, actual^.asunto, actual^.mensaje, estadoTexto);
      WriteLn('✅ Correo encontrado en cola: ', actual^.asunto, ' - Estado: ', estadoTexto);
    end;
    actual := actual^.siguiente;
  end;
end;

procedure ActualizarEstadoCorreo(cola: TCola; correoID: Integer);
begin
  WriteLn('DEBUG - Actualizando estado del correo ID: ', correoID);
  
  // Solo actualizar si está como No Leído
  if ObtenerEstadoCorreo(correoID) = 'NL' then
  begin
    EstablecerEstadoCorreo(correoID, 'L');
    WriteLn('✅ Estado actualizado a LEÍDO para correo ID: ', correoID);
  end;
end;

function ContarCorreos(lista: PCorreoRecibido): Integer;
var
  actual: PCorreoRecibido;
  count: Integer;
begin
  count := 0;
  actual := lista;
  while actual <> nil do
  begin
    Inc(count);
    actual := actual^.siguiente;
  end;
  Result := count;
end;

function ObtenerCorreosRecibidos(const emailDestino: String): PCorreoRecibido;
var
  lista: PCorreoRecibido;
begin
  lista := nil;
  
  WriteLn('🔍 Buscando correos SOLO en Cola para: ', emailDestino);
  
  // SOLO buscar en la Cola - los correos enviados van aquí
  if GProgramados <> nil then
    BuscarCorreosEnCola(lista, GProgramados^, emailDestino);
  
  WriteLn('📊 Total de correos encontrados para ', emailDestino, ': ', ContarCorreos(lista));
  Result := lista;
end;

// Declaraciones forward
procedure CargarCorreosEnLista(lista: PCorreoRecibido); forward;

procedure CargarCorreosEnLista(lista: PCorreoRecibido);
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actual: PCorreoRecibido;
  idStr: String;
begin
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaCorreos)));
  gtk_list_store_clear(store);
  
  actual := lista;
  while actual <> nil do
  begin
    idStr := IntToStr(actual^.id);
    
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 
                       0, PChar(idStr),
                       1, PChar(actual^.remitente),
                       2, PChar(actual^.asunto),
                       3, PChar(actual^.mensaje),
                       4, PChar(actual^.estado),
                       -1);
    
    actual := actual^.siguiente;
  end;
end;

procedure OnSeleccionarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
var
  selection: PGtkTreeSelection;
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  idStr, remitente, asunto, mensaje, estado: PChar;
  textoCompleto: String;
  buffer: PGtkTextBuffer;
  correoID: Integer;
  lista: PCorreoRecibido;
begin
  selection := gtk_tree_view_get_selection(PGtkTreeView(ListaCorreos));
  
  if gtk_tree_selection_get_selected(selection, @model, @iter) then
  begin
    gtk_tree_model_get(model, @iter, 0, @idStr, 1, @remitente, 2, @asunto, 3, @mensaje, 4, @estado, -1);
    
    // Actualizar estado del correo a LEÍDO
    correoID := StrToIntDef(StrPas(idStr), 0);
    if correoID > 0 then
      ActualizarEstadoCorreo(GProgramados^, correoID);
    
    textoCompleto := '📧 CORREO RECIBIDO' + LineEnding + 
                     '═══════════════════' + LineEnding + LineEnding +
                     '🆔 ID: ' + StrPas(idStr) + LineEnding +
                     '📤 De: ' + StrPas(remitente) + LineEnding + 
                     '📥 Para: ' + GEmailUsuario + LineEnding +
                     '📊 Estado: ' + StrPas(estado) + ' → ✅ Leído' + LineEnding + LineEnding +
                     '📋 Asunto: ' + StrPas(asunto) + LineEnding + LineEnding +
                     '💬 Mensaje:' + LineEnding + 
                     '──────────────────' + LineEnding +
                     StrPas(mensaje);
    
    buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
    gtk_text_buffer_set_text(buffer, PChar(textoCompleto), -1);
    
    // Actualizar la lista manualmente para evitar referencia circular
    lista := ObtenerCorreosRecibidos(GEmailUsuario);
    CargarCorreosEnLista(lista);
    LiberarListaCorreos(lista);
    
    g_free(idStr);
    g_free(remitente);
    g_free(asunto);
    g_free(mensaje);
    g_free(estado);
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
  lblTitulo, lblLista, lblDetalle, lblInfo: PGtkWidget;
  btnActualizar, btnCerrar, btnBox: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  lista: PCorreoRecibido;
begin
  // Guardar referencias globales
  GEmailUsuario := emailUsuario;
  GProgramados := @programados;

  // Si existe una ventana previa, destruirla
  if Assigned(BandejaWindow) then
    gtk_widget_destroy(BandejaWindow);

  BandejaWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(BandejaWindow), PChar('📥 Bandeja de Entrada - ' + emailUsuario));
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

  lblTitulo := gtk_label_new(PChar('📥 Correos Recibidos'));
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblTitulo, False, False, 0);

  lblInfo := gtk_label_new(PChar('Correos de la Cola (JSON + Enviados)'));
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblInfo, False, False, 0);

  lblLista := gtk_label_new('Lista de correos:');
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblLista, False, False, 0);

  // Lista de correos
  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxIzq), scrolledLista, True, True, 0);

  // Crear modelo y vista CON columna estado
  store := gtk_list_store_new(5, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
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

  column := gtk_tree_view_column_new_with_attributes('Estado', renderer, 'text', 4, nil);
  gtk_tree_view_column_set_min_width(column, 120);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaCorreos), column);

  // Conectar selección
  g_signal_connect(gtk_tree_view_get_selection(PGtkTreeView(ListaCorreos)), 
                   'changed', G_CALLBACK(@OnSeleccionarCorreo), nil);

  // Botones
  btnBox := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox, False, False, 0);

  btnActualizar := gtk_button_new_with_label('🔄 Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarBandeja), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnActualizar, True, True, 0);

  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarBandeja), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, True, True, 0);

  // Panel derecho - Detalle del correo
  vboxDer := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxDer), 10);
  gtk_paned_add2(GTK_PANED(hpaned), vboxDer);

  lblDetalle := gtk_label_new('📄 Detalle del correo:');
  gtk_box_pack_start(GTK_BOX(vboxDer), lblDetalle, False, False, 0);

  scrolledDetalle := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDetalle), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxDer), scrolledDetalle, True, True, 0);

  TextViewDetalle := gtk_text_view_new();
  gtk_text_view_set_editable(PGtkTextView(TextViewDetalle), False);
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDetalle), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDetalle), TextViewDetalle);

  // Cargar correos dinámicos iniciales
  WriteLn('🔍 Iniciando búsqueda de correos para: "', emailUsuario, '"');
  lista := ObtenerCorreosRecibidos(emailUsuario);
  CargarCorreosEnLista(lista);
  LiberarListaCorreos(lista);

  gtk_widget_show_all(BandejaWindow);
end;

end.
