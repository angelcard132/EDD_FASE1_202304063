unit borradores;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  arbol_avl, cola2, json_loader;

procedure MostrarGestorBorradores(const emailUsuario: String; var borradores: PCorreoAVL; var programados: TCola);

implementation

type
  PBorradorUI = ^TBorradorUI;
  TBorradorUI = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
    siguiente: PBorradorUI;
  end;

var
  GEmailUsuario: String;
  GBorradores: ^PCorreoAVL;
  GProgramados: ^TCola;
  
  BorradoresWindow: PGtkWidget;
  ListaBorradores: PGtkWidget;
  EntryDestinatario, EntryAsunto: PGtkWidget;
  TextViewMensaje: PGtkWidget;
  LabelInfo: PGtkWidget;
  
  BorradorSeleccionado: Integer;
  ContadorID: Integer;

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

procedure LiberarListaBorradoresUI(var lista: PBorradorUI);
var
  actual, temp: PBorradorUI;
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

procedure AgregarBorradorALista(var lista: PBorradorUI; id: Integer; const remitente, destinatario, asunto, mensaje: String);
var
  nuevo: PBorradorUI;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;
  nuevo^.asunto := asunto;
  nuevo^.mensaje := mensaje;
  nuevo^.siguiente := lista;
  lista := nuevo;
end;

// Callback para recorrido personalizado del AVL - sin cdecl
procedure CallbackRecolectarBorradores(correo: PCorreoAVL; data: Pointer);
var
  lista: ^PBorradorUI;
begin
  if (correo <> nil) and (data <> nil) then
  begin
    lista := PPointer(data)^;
    if correo^.remitente = GEmailUsuario then
      AgregarBorradorALista(lista^, correo^.id, correo^.remitente, correo^.destinatario, correo^.asunto, correo^.mensaje);
  end;
end;

function ObtenerBorradoresDelUsuario: PBorradorUI;
var
  lista: PBorradorUI;
  pLista: Pointer;
begin
  lista := nil;
  pLista := @lista;
  
  if (GBorradores <> nil) and (GBorradores^ <> nil) then
    RecorridoPersonalizado(GBorradores^, @CallbackRecolectarBorradores, @pLista);
  
  Result := lista;
end;

procedure CargarBorradoresEnLista;
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  lista, actual: PBorradorUI;
  idStr: String;
begin
  if ListaBorradores = nil then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaBorradores)));
  if store = nil then Exit;
  
  gtk_list_store_clear(store);
  
  lista := ObtenerBorradoresDelUsuario;
  actual := lista;
  
  while actual <> nil do
  begin
    idStr := IntToStr(actual^.id);
    
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(SanearUTF8(idStr)),
                       1, PChar(SanearUTF8(actual^.destinatario)),
                       2, PChar(SanearUTF8(actual^.asunto)),
                       3, PChar(Copy(SanearUTF8(actual^.mensaje), 1, 50) + '...'),
                       -1);
    
    actual := actual^.siguiente;
  end;
  
  LiberarListaBorradoresUI(lista);
  
  // Actualizar información
  if LabelInfo <> nil then
  begin
    if GBorradores^ <> nil then
      gtk_label_set_text(GTK_LABEL(LabelInfo), PChar('Total borradores: ' + IntToStr(ContarNodos(GBorradores^))))
    else
      gtk_label_set_text(GTK_LABEL(LabelInfo), 'No hay borradores');
  end;
end;

procedure LimpiarFormulario;
begin
  if EntryDestinatario <> nil then
    gtk_entry_set_text(GTK_ENTRY(EntryDestinatario), '');
  if EntryAsunto <> nil then
    gtk_entry_set_text(GTK_ENTRY(EntryAsunto), '');
  if TextViewMensaje <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewMensaje)), '', -1);
  
  BorradorSeleccionado := 0;
end;

procedure OnSeleccionarBorrador(widget: PGtkWidget; data: gpointer); cdecl;
var
  selection: PGtkTreeSelection;
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  idStr: PChar;
  correoID: Integer;
  nodo: PCorreoAVL;
  buffer: PGtkTextBuffer;
begin
  if ListaBorradores = nil then Exit;
  
  selection := gtk_tree_view_get_selection(PGtkTreeView(ListaBorradores));
  if selection = nil then Exit;
  
  if gtk_tree_selection_get_selected(selection, @model, @iter) then
  begin
    idStr := nil;
    gtk_tree_model_get(model, @iter, 0, @idStr, -1);
    
    if idStr <> nil then
    begin
      correoID := StrToIntDef(StrPas(idStr), 0);
      g_free(idStr);
      
      if correoID <> 0 then
      begin
        nodo := Buscar(GBorradores^, correoID);
        if nodo <> nil then
        begin
          BorradorSeleccionado := correoID;
          
          gtk_entry_set_text(GTK_ENTRY(EntryDestinatario), PChar(AnsiString(nodo^.destinatario)));
          gtk_entry_set_text(GTK_ENTRY(EntryAsunto), PChar(AnsiString(nodo^.asunto)));
          
          buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewMensaje));
          gtk_text_buffer_set_text(buffer, PChar(AnsiString(nodo^.mensaje)), -1);
          
          WriteLn('📝 Borrador seleccionado ID: ', correoID);
        end;
      end;
    end;
  end;
end;

procedure OnNuevoBorrador(widget: PGtkWidget; data: gpointer); cdecl;
begin
  LimpiarFormulario;
  WriteLn('📝 Nuevo borrador iniciado');
end;

procedure OnGuardarBorrador(widget: PGtkWidget; data: gpointer); cdecl;
var
  destinatario, asunto, mensaje: String;
  buffer: PGtkTextBuffer;
  start_iter, end_iter: TGtkTextIter;
  texto: PChar;
  nuevoID: Integer;
begin
  destinatario := StrPas(gtk_entry_get_text(GTK_ENTRY(EntryDestinatario)));
  asunto := StrPas(gtk_entry_get_text(GTK_ENTRY(EntryAsunto)));
  
  buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewMensaje));
  gtk_text_buffer_get_start_iter(buffer, @start_iter);
  gtk_text_buffer_get_end_iter(buffer, @end_iter);
  texto := gtk_text_buffer_get_text(buffer, @start_iter, @end_iter, False);
  mensaje := StrPas(texto);
  g_free(texto);
  
  if (destinatario = '') or (asunto = '') then
  begin
    WriteLn('⚠️ Destinatario y asunto son obligatorios');
    Exit;
  end;
  
  if BorradorSeleccionado > 0 then
  begin
    // Actualizar borrador existente
    if Actualizar(GBorradores^, BorradorSeleccionado, GEmailUsuario, destinatario, asunto, mensaje) then
    begin
      WriteLn('✅ Borrador actualizado ID: ', BorradorSeleccionado);
      CargarBorradoresEnLista;
    end
    else
      WriteLn('❌ Error al actualizar borrador');
  end
  else
  begin
    // Crear nuevo borrador
    Inc(ContadorID);
    nuevoID := ContadorID;
    GBorradores^ := Insertar(GBorradores^, nuevoID, GEmailUsuario, destinatario, asunto, mensaje);
    
    WriteLn('✅ Nuevo borrador guardado ID: ', nuevoID);
    CargarBorradoresEnLista;
    LimpiarFormulario;
  end;
end;

procedure OnEliminarBorrador(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if BorradorSeleccionado > 0 then
  begin
    GBorradores^ := Eliminar(GBorradores^, BorradorSeleccionado);
    WriteLn('🗑️ Borrador eliminado ID: ', BorradorSeleccionado);
    
    CargarBorradoresEnLista;
    LimpiarFormulario;
  end
  else
    WriteLn('⚠️ Selecciona un borrador para eliminar');
end;

procedure OnEnviarBorrador(widget: PGtkWidget; data: gpointer); cdecl;
var
  nodo: PCorreoAVL;
begin
  if BorradorSeleccionado > 0 then
  begin
    nodo := Buscar(GBorradores^, BorradorSeleccionado);
    if nodo <> nil then
    begin
      // Enviar a cola de programados
      Encolar(GProgramados^, BorradorSeleccionado, nodo^.remitente, nodo^.destinatario, nodo^.asunto, nodo^.mensaje);
      EstablecerEstadoCorreo(BorradorSeleccionado, 'NL');
      
      // Eliminar del AVL de borradores
      GBorradores^ := Eliminar(GBorradores^, BorradorSeleccionado);
      
      WriteLn('📤 Borrador enviado ID: ', BorradorSeleccionado);
      CargarBorradoresEnLista;
      LimpiarFormulario;
    end;
  end
  else
    WriteLn('⚠️ Selecciona un borrador para enviar');
end;

procedure OnRecorridoInOrden(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('📋 Recorrido In-Orden de borradores:');
  ListarBorradorsPorRemitente(GBorradores^, GEmailUsuario);
end;

procedure OnRecorridoPreOrden(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('📋 Recorrido Pre-Orden de borradores:');
  PreOrden(GBorradores^);
end;

procedure OnRecorridoPostOrden(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('📋 Recorrido Post-Orden de borradores:');
  PostOrden(GBorradores^);
end;

procedure OnCerrarBorradores(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(BorradoresWindow) then
    gtk_widget_destroy(BorradoresWindow);
end;

function OnDeleteEventBorradores(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando gestor de borradores...');
  if Assigned(BorradoresWindow) then
    gtk_widget_destroy(BorradoresWindow);
  Result := True;
end;

procedure MostrarGestorBorradores(const emailUsuario: String; var borradores: PCorreoAVL; var programados: TCola);
var
  hpaned, vboxIzq, vboxDer, scrolledLista, scrolledMensaje: PGtkWidget;
  lblTitulo, lblDestinatario, lblAsunto, lblMensaje: PGtkWidget;
  btnNuevo, btnGuardar, btnEliminar, btnEnviar: PGtkWidget;
  btnInOrden, btnPreOrden, btnPostOrden, btnCerrar: PGtkWidget;
  btnBox1, btnBox2, formBox: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
begin
  // Inicializar variables globales
  GEmailUsuario := emailUsuario;
  GBorradores := @borradores;
  GProgramados := @programados;
  BorradorSeleccionado := 0;
  ContadorID := 1000;
  
  if Assigned(BorradoresWindow) then
    gtk_widget_destroy(BorradoresWindow);
  
  BorradoresWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(BorradoresWindow), PChar(AnsiString('Gestor de Borradores - ' + emailUsuario)));
  gtk_window_set_default_size(GTK_WINDOW(BorradoresWindow), 1200, 700);
  g_signal_connect(BorradoresWindow, 'delete-event', G_CALLBACK(@OnDeleteEventBorradores), nil);
  
  hpaned := gtk_hpaned_new();
  gtk_container_add(GTK_CONTAINER(BorradoresWindow), hpaned);
  
  // Panel izquierdo - Lista de borradores
  vboxIzq := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxIzq), 10);
  gtk_paned_add1(GTK_PANED(hpaned), vboxIzq);
  
  lblTitulo := gtk_label_new('Borradores Guardados');
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblTitulo, False, False, 0);
  
  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxIzq), scrolledLista, True, True, 0);
  
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaBorradores := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaBorradores);
  
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 60);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBorradores), column);
  
  column := gtk_tree_view_column_new_with_attributes('Para', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBorradores), column);
  
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBorradores), column);
  
  column := gtk_tree_view_column_new_with_attributes('Vista previa', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBorradores), column);
  
  g_signal_connect(gtk_tree_view_get_selection(PGtkTreeView(ListaBorradores)), 
                   'changed', G_CALLBACK(@OnSeleccionarBorrador), nil);
  
  // Botones de recorridos
  btnBox2 := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox2, False, False, 0);
  
  btnInOrden := gtk_button_new_with_label('In-Orden');
  g_signal_connect(btnInOrden, 'clicked', G_CALLBACK(@OnRecorridoInOrden), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnInOrden, True, True, 0);
  
  btnPreOrden := gtk_button_new_with_label('Pre-Orden');
  g_signal_connect(btnPreOrden, 'clicked', G_CALLBACK(@OnRecorridoPreOrden), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnPreOrden, True, True, 0);
  
  btnPostOrden := gtk_button_new_with_label('Post-Orden');
  g_signal_connect(btnPostOrden, 'clicked', G_CALLBACK(@OnRecorridoPostOrden), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnPostOrden, True, True, 0);
  
  LabelInfo := gtk_label_new('');
  gtk_box_pack_start(GTK_BOX(vboxIzq), LabelInfo, False, False, 0);
  
  // Panel derecho - Editor
  vboxDer := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxDer), 10);
  gtk_paned_add2(GTK_PANED(hpaned), vboxDer);
  
  // Formulario
  formBox := gtk_vbox_new(False, 5);
  gtk_box_pack_start(GTK_BOX(vboxDer), formBox, False, False, 0);
  
  lblDestinatario := gtk_label_new('Destinatario:');
  gtk_misc_set_alignment(GTK_MISC(lblDestinatario), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(formBox), lblDestinatario, False, False, 0);
  
  EntryDestinatario := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(formBox), EntryDestinatario, False, False, 0);
  
  lblAsunto := gtk_label_new('Asunto:');
  gtk_misc_set_alignment(GTK_MISC(lblAsunto), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(formBox), lblAsunto, False, False, 0);
  
  EntryAsunto := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(formBox), EntryAsunto, False, False, 0);
  
  lblMensaje := gtk_label_new('Mensaje:');
  gtk_misc_set_alignment(GTK_MISC(lblMensaje), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(formBox), lblMensaje, False, False, 0);
  
  scrolledMensaje := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledMensaje), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxDer), scrolledMensaje, True, True, 0);
  
  TextViewMensaje := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewMensaje), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledMensaje), TextViewMensaje);
  
  // Botones de acción
  btnBox1 := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxDer), btnBox1, False, False, 0);
  
  btnNuevo := gtk_button_new_with_label('Nuevo');
  g_signal_connect(btnNuevo, 'clicked', G_CALLBACK(@OnNuevoBorrador), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnNuevo, True, True, 0);
  
  btnGuardar := gtk_button_new_with_label('Guardar');
  g_signal_connect(btnGuardar, 'clicked', G_CALLBACK(@OnGuardarBorrador), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnGuardar, True, True, 0);
  
  btnEliminar := gtk_button_new_with_label('Eliminar');
  g_signal_connect(btnEliminar, 'clicked', G_CALLBACK(@OnEliminarBorrador), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnEliminar, True, True, 0);
  
  btnEnviar := gtk_button_new_with_label('Enviar');
  g_signal_connect(btnEnviar, 'clicked', G_CALLBACK(@OnEnviarBorrador), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnEnviar, True, True, 0);
  
  btnCerrar := gtk_button_new_with_label('Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarBorradores), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnCerrar, True, True, 0);
  
  CargarBorradoresEnLista;
  gtk_widget_show_all(BorradoresWindow);
end;

end.
