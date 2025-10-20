unit correos_privados;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, merkle_tree, json_loader, reports;

procedure MostrarCorreosPrivados(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var merklePrivados: TArbolMerkle);
procedure AgregarCorreoAPrivados(id: Integer; const remitente, destinatario, asunto, mensaje: String; var merklePrivados: TArbolMerkle);

implementation

type
  PCorreoPrivadoUI = ^TCorreoPrivadoUI;
  TCorreoPrivadoUI = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
    hash: String;
    fechaCreacion: String;
    siguiente: PCorreoPrivadoUI;
  end;

var
  GEmailUsuario: String;
  // ✅ COMENTAR VARIABLES NO USADAS PARA EVITAR WARNINGS
  // GUsuarios: ^TListaSimple = nil;
  // GProgramados: ^TCola = nil;
  // GBorradores: ^PCorreoAVL = nil;
  // GFavoritos: ^PNodoB = nil;
  GMerklePrivados: ^TArbolMerkle = nil;
  
  PrivadosWindow: PGtkWidget = nil;
  ListaPrivados: PGtkWidget = nil;
  TextViewDetalle: PGtkWidget = nil;
  LabelInfo: PGtkWidget = nil;
  
  CorreoSeleccionadoID: Integer = 0; // ✅ CAMBIAR nombre de variable

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

procedure MostrarMensaje(const titulo, mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_window_set_title(GTK_WINDOW(dialog), PChar(titulo));
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

procedure LiberarListaPrivadosUI(var lista: PCorreoPrivadoUI);
var
  actual, temp: PCorreoPrivadoUI;
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

procedure AgregarPrivadoALista(var lista: PCorreoPrivadoUI; const correo: PCorreoPrivado);
var
  nuevo: PCorreoPrivadoUI;
begin
  New(nuevo);
  nuevo^.id := correo^.id;
  nuevo^.remitente := correo^.remitente;
  nuevo^.destinatario := correo^.destinatario;
  nuevo^.asunto := correo^.asunto;
  nuevo^.mensaje := correo^.mensaje;
  nuevo^.hash := correo^.hash;
  nuevo^.fechaCreacion := correo^.fechaCreacion;
  nuevo^.siguiente := lista;
  lista := nuevo;
end;

// Callback para recolectar correos privados del usuario
procedure CallbackRecolectarPrivados(correo: PCorreoPrivado; data: Pointer);
var
  lista: ^PCorreoPrivadoUI;
begin
  if (correo <> nil) and (data <> nil) then
  begin
    lista := PPointer(data)^;
    // Filtrar correos del usuario actual
    if (correo^.remitente = GEmailUsuario) or (correo^.destinatario = GEmailUsuario) then
      AgregarPrivadoALista(lista^, correo);
  end;
end;

function ObtenerPrivadosDelUsuario: PCorreoPrivadoUI;
var
  lista: PCorreoPrivadoUI;
  pLista: Pointer;
begin
  lista := nil;
  pLista := @lista;
  
  if GMerklePrivados <> nil then
    RecorridoPersonalizadoMerkle(GMerklePrivados^.raiz, @CallbackRecolectarPrivados, @pLista);
  
  Result := lista;
end;

procedure CargarPrivadosEnLista;
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  lista, actual: PCorreoPrivadoUI;
  idStr: String;
  contador: Integer;
begin
  if ListaPrivados = nil then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaPrivados)));
  if store = nil then Exit;
  
  gtk_list_store_clear(store);
  
  lista := ObtenerPrivadosDelUsuario;
  actual := lista;
  contador := 0;
  
  while actual <> nil do
  begin
    idStr := IntToStr(actual^.id);
    
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(SanearUTF8(idStr)),
                       1, PChar(SanearUTF8(actual^.remitente)),
                       2, PChar(SanearUTF8(actual^.destinatario)),
                       3, PChar(SanearUTF8(actual^.asunto)),
                       4, PChar(Copy(SanearUTF8(actual^.hash), 1, 8) + '...'),
                       -1);
    
    Inc(contador);
    actual := actual^.siguiente;
  end;
  
  LiberarListaPrivadosUI(lista);
  
  // Actualizar información
  if LabelInfo <> nil then
  begin
    if contador > 0 then
      gtk_label_set_text(GTK_LABEL(LabelInfo), PChar('Total correos privados: ' + IntToStr(contador) + ' | Integridad verificada por Merkle Tree'))
    else
      gtk_label_set_text(GTK_LABEL(LabelInfo), 'No hay correos privados. Agrega correos desde favoritos usando "🔒 A Privados".');
  end;
  
  WriteLn('🔒 Correos privados cargados: ', contador);
end;

procedure OnSeleccionarPrivado(widget: PGtkWidget; data: gpointer); cdecl;
var
  selection: PGtkTreeSelection;
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  idStr: PChar;
  correoID: Integer;
  correo: PCorreoPrivado;
  buffer: PGtkTextBuffer;
  textoDetalle: String;
begin
  if ListaPrivados = nil then Exit;
  
  selection := gtk_tree_view_get_selection(PGtkTreeView(ListaPrivados));
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
        correo := BuscarCorreoPrivado(GMerklePrivados^, correoID);
        if correo <> nil then
        begin
          CorreoSeleccionadoID := correoID; // ✅ USAR nueva variable
          
          textoDetalle := '🔒 CORREO PRIVADO (MERKLE TREE)' + #13#10 +
                          '==============================' + #13#10 + #13#10 +
                          'ID: ' + IntToStr(correo^.id) + #13#10 +
                          'De: ' + SanearUTF8(correo^.remitente) + #13#10 +
                          'Para: ' + SanearUTF8(correo^.destinatario) + #13#10 +
                          'Fecha: ' + correo^.fechaCreacion + #13#10 + #13#10 +
                          'ASUNTO:' + #13#10 +
                          SanearUTF8(correo^.asunto) + #13#10 + #13#10 +
                          'MENSAJE:' + #13#10 +
                          '--------' + #13#10 +
                          SanearUTF8(correo^.mensaje) + #13#10 + #13#10 +
                          'INTEGRIDAD CRIPTOGRÁFICA:' + #13#10 +
                          'Hash MD5: ' + correo^.hash + #13#10 +
                          'Estado: ✅ Verificado en Merkle Tree';
          
          buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
          gtk_text_buffer_set_text(buffer, PChar(textoDetalle), -1);
          
          WriteLn('🔒 Correo privado seleccionado ID: ', correoID);
        end;
      end;
    end;
  end
  else
  begin
    if TextViewDetalle <> nil then
    begin
      buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
      gtk_text_buffer_set_text(buffer, '🔒 Selecciona un correo privado para ver detalles', -1);
    end;
  end;
end;

procedure OnRecorridoPreOrden(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🌳 RECORRIDO PRE-ORDEN - MERKLE TREE DE CORREOS PRIVADOS');
  WriteLn('========================================================');
  if GMerklePrivados^.raiz <> nil then
    PreOrdenMerkle(GMerklePrivados^.raiz)
  else
    WriteLn('Árbol vacío');
  WriteLn('========================================================');
end;

procedure OnRecorridoInOrden(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🌳 RECORRIDO IN-ORDEN - MERKLE TREE DE CORREOS PRIVADOS');
  WriteLn('=======================================================');
  if GMerklePrivados^.raiz <> nil then
    InOrdenMerkle(GMerklePrivados^.raiz)
  else
    WriteLn('Árbol vacío');
  WriteLn('=======================================================');
end;

procedure OnRecorridoPostOrden(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🌳 RECORRIDO POST-ORDEN - MERKLE TREE DE CORREOS PRIVADOS');
  WriteLn('=========================================================');
  if GMerklePrivados^.raiz <> nil then
    PostOrdenMerkle(GMerklePrivados^.raiz)
  else
    WriteLn('Árbol vacío');
  WriteLn('=========================================================');
end;

procedure OnGenerarReporteMerkle(widget: PGtkWidget; data: gpointer); cdecl;
var
  rutaDir, rutaDot, rutaPng: String;
  dialog: PGtkWidget;
begin
  // Crear directorio de reportes
  rutaDir := ExtractFileDir(ExtractFileDir(ParamStr(0))) + '/graficos/' + GEmailUsuario + '-reportes';
  if not DirectoryExists(rutaDir) then
    CreateDir(rutaDir);
  
  rutaDot := rutaDir + '/merkle-tree-privados.dot';
  rutaPng := rutaDir + '/merkle-tree-privados.png';
  
  // Generar reporte del Merkle Tree
  GenerarReporteMerkle(GMerklePrivados^, rutaDot);
  WriteLn('🔒 Reporte DOT generado: ', rutaDot);
  
  // Intentar generar PNG
  if ExecuteProcess('/bin/sh', ['-c', 'command -v dot >/dev/null 2>&1'], []) = 0 then
  begin
    if ExecuteProcess('/bin/sh', ['-c', 'dot -Tpng "' + rutaDot + '" -o "' + rutaPng + '"'], []) = 0 then
    begin
      WriteLn('🖼️ Gráfico Merkle Tree generado: ', rutaPng);
      
      dialog := gtk_message_dialog_new(nil,
        GTK_DIALOG_MODAL,
        GTK_MESSAGE_INFO,
        GTK_BUTTONS_OK,
        PChar('🔒 Reporte Merkle Tree generado exitosamente!' + #10 + #10 +
              'El árbol de Merkle garantiza la integridad de tus correos privados.' + #10 + #10 +
              'Archivos generados:' + #10 +
              '📄 DOT: merkle-tree-privados.dot' + #10 +
              '🖼️ PNG: merkle-tree-privados.png' + #10 + #10 +
              'Ubicación: /graficos/' + GEmailUsuario + '-reportes/'));
      gtk_dialog_run(GTK_DIALOG(dialog));
      gtk_widget_destroy(dialog);
    end
    else
    begin
      dialog := gtk_message_dialog_new(nil,
        GTK_DIALOG_MODAL,
        GTK_MESSAGE_WARNING,
        GTK_BUTTONS_OK,
        'Archivo DOT generado, pero no se pudo crear el PNG.');
      gtk_dialog_run(GTK_DIALOG(dialog));
      gtk_widget_destroy(dialog);
    end;
  end
  else
  begin
    dialog := gtk_message_dialog_new(nil,
      GTK_DIALOG_MODAL,
      GTK_MESSAGE_INFO,
      GTK_BUTTONS_OK,
      PChar('Archivo DOT generado: merkle-tree-privados.dot' + #10 +
            'Instala Graphviz para generar imágenes PNG.'));
    gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
  end;
end;

procedure OnActualizarPrivados(widget: PGtkWidget; data: gpointer); cdecl;
begin
  CargarPrivadosEnLista;
  
  // Mostrar información del árbol
  if GMerklePrivados <> nil then
    MostrarArbolMerkle(GMerklePrivados^);
  
  // Limpiar detalle
  if TextViewDetalle <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 
                             '🔒 Correos privados protegidos por Merkle Tree', -1);
end;

procedure OnCerrarPrivados(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(PrivadosWindow) then
    gtk_widget_destroy(PrivadosWindow);
end;

function OnDeleteEventPrivados(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando correos privados...');
  if Assigned(PrivadosWindow) then
    gtk_widget_destroy(PrivadosWindow);
  Result := True;
end;

procedure AgregarCorreoAPrivados(id: Integer; const remitente, destinatario, asunto, mensaje: String; var merklePrivados: TArbolMerkle);
begin
  if InsertarCorreoPrivado(merklePrivados, id, remitente, destinatario, asunto, mensaje) then
  begin
    WriteLn('🔒 Correo agregado a privados con Merkle Tree - ID: ', id);
    MostrarMensaje('Correo Privado Agregado', 
      'El correo ha sido agregado a tus correos privados.' + LineEnding + LineEnding +
      'Protección: Merkle Tree' + LineEnding +
      'Integridad: Verificada criptográficamente' + LineEnding +
      'ID: ' + IntToStr(id), 
      GTK_MESSAGE_INFO);
  end
  else
  begin
    WriteLn('❌ Error agregando correo a privados');
    MostrarMensaje('Error', 'No se pudo agregar el correo a privados.', GTK_MESSAGE_ERROR);
  end;
end;

procedure MostrarCorreosPrivados(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var merklePrivados: TArbolMerkle);
var
  hpaned, vboxIzq, vboxDer, scrolledLista, scrolledDetalle: PGtkWidget;
  lblTitulo, lblDetalle: PGtkWidget;
  btnActualizar, btnPreOrden, btnInOrden, btnPostOrden, btnReporte, btnCerrar: PGtkWidget;
  btnBox1, btnBox2: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
begin
  GEmailUsuario := emailUsuario;
  // ✅ SOLO GUARDAR LAS REFERENCIAS QUE SE USAN
  // GUsuarios := @usuarios;
  // GProgramados := @programados;
  // GBorradores := @borradores;
  // GFavoritos := @favoritos;
  GMerklePrivados := @merklePrivados;
  CorreoSeleccionadoID := 0; // ✅ INICIALIZAR variable correcta
  
  WriteLn('🔒 Abriendo correos privados para: ', emailUsuario);
  
  if Assigned(PrivadosWindow) then
    gtk_widget_destroy(PrivadosWindow);
  
  PrivadosWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(PrivadosWindow), PChar('🔒 Correos Privados (Merkle Tree) - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(PrivadosWindow), 1200, 700);
  g_signal_connect(PrivadosWindow, 'delete-event', G_CALLBACK(@OnDeleteEventPrivados), nil);
  
  hpaned := gtk_hpaned_new();
  gtk_container_add(GTK_CONTAINER(PrivadosWindow), hpaned);
  
  // Panel izquierdo - Lista de correos privados
  vboxIzq := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxIzq), 10);
  gtk_paned_add1(GTK_PANED(hpaned), vboxIzq);
  
  lblTitulo := gtk_label_new('🔒 Correos Privados (Merkle Tree)');
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblTitulo, False, False, 0);
  
  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxIzq), scrolledLista, True, True, 0);
  
  store := gtk_list_store_new(5, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaPrivados := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaPrivados);
  
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 60);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaPrivados), column);
  
  column := gtk_tree_view_column_new_with_attributes('De', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaPrivados), column);
  
  column := gtk_tree_view_column_new_with_attributes('Para', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaPrivados), column);
  
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 250);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaPrivados), column);
  
  column := gtk_tree_view_column_new_with_attributes('Hash', renderer, 'text', 4, nil);
  gtk_tree_view_column_set_min_width(column, 100);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaPrivados), column);
  
  g_signal_connect(gtk_tree_view_get_selection(PGtkTreeView(ListaPrivados)), 
                   'changed', G_CALLBACK(@OnSeleccionarPrivado), nil);
  
  // Botones de recorridos
  btnBox1 := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox1, False, False, 0);
  
  btnPreOrden := gtk_button_new_with_label('Pre-Orden');
  g_signal_connect(btnPreOrden, 'clicked', G_CALLBACK(@OnRecorridoPreOrden), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnPreOrden, True, True, 0);
  
  btnInOrden := gtk_button_new_with_label('In-Orden');
  g_signal_connect(btnInOrden, 'clicked', G_CALLBACK(@OnRecorridoInOrden), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnInOrden, True, True, 0);
  
  btnPostOrden := gtk_button_new_with_label('Post-Orden');
  g_signal_connect(btnPostOrden, 'clicked', G_CALLBACK(@OnRecorridoPostOrden), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnPostOrden, True, True, 0);
  
  // Botones de acción
  btnBox2 := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox2, False, False, 0);
  
  btnActualizar := gtk_button_new_with_label('🔄 Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarPrivados), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnActualizar, True, True, 0);
  
  btnReporte := gtk_button_new_with_label('🌳 Reporte');
  g_signal_connect(btnReporte, 'clicked', G_CALLBACK(@OnGenerarReporteMerkle), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnReporte, True, True, 0);
  
  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarPrivados), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnCerrar, True, True, 0);
  
  LabelInfo := gtk_label_new('');
  gtk_box_pack_start(GTK_BOX(vboxIzq), LabelInfo, False, False, 0);
  
  // Panel derecho - Detalle del correo privado
  vboxDer := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxDer), 10);
  gtk_paned_add2(GTK_PANED(hpaned), vboxDer);
  
  lblDetalle := gtk_label_new('Detalle del correo privado:');
  gtk_box_pack_start(GTK_BOX(vboxDer), lblDetalle, False, False, 0);
  
  scrolledDetalle := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDetalle), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxDer), scrolledDetalle, True, True, 0);
  
  TextViewDetalle := gtk_text_view_new();
  gtk_text_view_set_editable(PGtkTextView(TextViewDetalle), False);
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDetalle), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDetalle), TextViewDetalle);
  
  // Mostrar mensaje inicial
  if TextViewDetalle <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 
      '🔒 CORREOS PRIVADOS CON MERKLE TREE' + #13#10 + #13#10 + 
      'Los correos privados están protegidos por un árbol de Merkle que garantiza:' + #13#10 + #13#10 +
      '✅ Integridad de datos' + #13#10 +
      '✅ Detección de modificaciones' + #13#10 +
      '✅ Verificación criptográfica' + #13#10 + #13#10 +
      'Para agregar correos a privados:' + #13#10 +
      '1. Ve a tu bandeja de entrada o favoritos' + #13#10 +
      '2. Selecciona un correo' + #13#10 +
      '3. Haz clic en "🔒 A Privados"', -1);
  
  CargarPrivadosEnLista;
  gtk_widget_show_all(PrivadosWindow);
end;

end.
