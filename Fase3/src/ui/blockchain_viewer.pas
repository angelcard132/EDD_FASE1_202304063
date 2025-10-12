unit blockchain_viewer;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  blockchain;

procedure MostrarBlockchainViewer(var blockchainMail: TBlockchain);

implementation

var
  BlockchainWindow: PGtkWidget = nil;
  ListaBloques: PGtkWidget = nil;
  TextViewDetalle: PGtkWidget = nil;
  LabelInfo: PGtkWidget = nil;
  
  BloqueSeleccionado: Integer = -1;

procedure OnSeleccionarBloque(widget: PGtkWidget; data: gpointer); cdecl;
var
  selection: PGtkTreeSelection;
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  indexStr: PChar;
  bloqueIndex: Integer;
  actual: PBloque;
  buffer: PGtkTextBuffer;
  textoDetalle: String;
  blockchainPtr: ^TBlockchain;
begin
  if ListaBloques = nil then Exit;
  
  selection := gtk_tree_view_get_selection(PGtkTreeView(ListaBloques));
  if selection = nil then Exit;
  
  if gtk_tree_selection_get_selected(selection, @model, @iter) then
  begin
    indexStr := nil;
    gtk_tree_model_get(model, @iter, 0, @indexStr, -1);
    
    if indexStr <> nil then
    begin
      bloqueIndex := StrToIntDef(StrPas(indexStr), -1);
      g_free(indexStr);
      
      if bloqueIndex >= 0 then
      begin
        BloqueSeleccionado := bloqueIndex;
        
        // Buscar bloque en la blockchain
        blockchainPtr := PPointer(data)^;
        actual := blockchainPtr^.cabeza;
        
        while actual <> nil do
        begin
          if actual^.index = bloqueIndex then
          begin
            // Construir texto detallado del bloque
            textoDetalle := '🔗 DETALLE DEL BLOQUE' + #13#10 +
                            '====================' + #13#10 + #13#10 +
                            'INDEX: ' + IntToStr(actual^.index) + #13#10 +
                            'TIMESTAMP: ' + actual^.timestamp + #13#10 +
                            'NONCE: ' + IntToStr(actual^.nonce) + #13#10 +
                            'PREVIOUS HASH: ' + actual^.previousHash + #13#10 +
                            'HASH: ' + actual^.hash + #13#10 + #13#10 +
                            'DATOS DEL CORREO:' + #13#10 +
                            '================='+#13#10 +
                            'ID: ' + IntToStr(actual^.data.id) + #13#10 +
                            'Remitente: ' + actual^.data.remitente + #13#10 +
                            'Destinatario: ' + actual^.data.destinatario + #13#10 +
                            'Asunto: ' + actual^.data.asunto + #13#10 + #13#10 +
                            'MENSAJE:' + #13#10 +
                            '--------' + #13#10 +
                            actual^.data.mensaje + #13#10 + #13#10 +
                            'VALIDACIÓN:' + #13#10 +
                            '===========' + #13#10;
            
            // Verificar si el hash es válido
            if actual^.hash = CalcularHash(actual^.index, actual^.timestamp, 
                                          CalcularHashData(actual^.data), 
                                          actual^.previousHash, actual^.nonce) then
              textoDetalle := textoDetalle + '✅ Hash válido' + #13#10
            else
              textoDetalle := textoDetalle + '❌ Hash inválido' + #13#10;
            
            // Verificar proof of work
            if Copy(actual^.hash, 1, blockchainPtr^.difficulty) = StringOfChar('0', blockchainPtr^.difficulty) then
              textoDetalle := textoDetalle + '✅ Proof of Work válido (' + IntToStr(blockchainPtr^.difficulty) + ' ceros)' + #13#10
            else
              textoDetalle := textoDetalle + '❌ Proof of Work inválido' + #13#10;
            
            buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
            gtk_text_buffer_set_text(buffer, PChar(textoDetalle), -1);
            
            WriteLn('🔗 Bloque seleccionado INDEX: ', bloqueIndex);
            Break;
          end;
          actual := actual^.siguiente;
        end;
      end;
    end;
  end
  else
  begin
    BloqueSeleccionado := -1;
    if TextViewDetalle <> nil then
    begin
      buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
      gtk_text_buffer_set_text(buffer, 'Selecciona un bloque para ver detalles', -1);
    end;
  end;
end;

procedure CargarBloquesEnLista(var blockchainMail: TBlockchain);
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actual: PBloque;
  indexStr: String;
  contador: Integer;
begin
  if ListaBloques = nil then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaBloques)));
  if store = nil then Exit;
  
  gtk_list_store_clear(store);
  
  contador := 0;
  actual := blockchainMail.cabeza;
  
  WriteLn('🔗 Cargando bloques en interfaz...');
  while actual <> nil do
  begin
    indexStr := IntToStr(actual^.index);
    
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(indexStr),
                       1, PChar(actual^.timestamp),
                       2, PChar(actual^.data.remitente),
                       3, PChar(actual^.data.destinatario),
                       4, PChar(actual^.data.asunto),
                       5, PChar(Copy(actual^.hash, 1, 16) + '...'),
                       6, PChar(IntToStr(actual^.nonce)),
                       -1);
    
    Inc(contador);
    WriteLn('✅ Bloque agregado a lista: INDEX ', actual^.index, ' - "', actual^.data.asunto, '"');
    actual := actual^.siguiente;
  end;
  
  WriteLn('📊 Total bloques mostrados en interfaz: ', contador);
end;

procedure OnValidarBlockchain(widget: PGtkWidget; data: gpointer); cdecl;
var
  blockchainPtr: ^TBlockchain;
  esValida: Boolean;
begin
  blockchainPtr := PPointer(data)^;
  
  WriteLn('🔍 Validando blockchain...');
  esValida := ValidarBlockchain(blockchainPtr^);
  
  if esValida then
    gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_OK, 
                          '✅ Blockchain válida' + #10 + #10 + 
                          'Todos los bloques tienen:' + #10 +
                          '- Hashes correctos' + #10 +
                          '- Proof of Work válido' + #10 +
                          '- Enlaces consistentes')
  else
    gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, GTK_MESSAGE_ERROR, GTK_BUTTONS_OK,
                          '❌ Blockchain inválida' + #10 + #10 +
                          'Se detectaron inconsistencias en la cadena');
end;

procedure OnMostrarBlockchainConsola(widget: PGtkWidget; data: gpointer); cdecl;
var
  blockchainPtr: ^TBlockchain;
begin
  blockchainPtr := PPointer(data)^;
  MostrarBlockchain(blockchainPtr^);
end;

procedure OnGenerarReporteBlockchain(widget: PGtkWidget; data: gpointer); cdecl;
var
  blockchainPtr: ^TBlockchain;
  rutaDir, rutaDot, rutaPng: String;
begin
  blockchainPtr := PPointer(data)^;
  
  // Crear directorio para reportes blockchain
  rutaDir := ExtractFileDir(ExtractFileDir(ParamStr(0))) + '/graficos/blockchain';
  if not DirectoryExists(rutaDir) then
    CreateDir(rutaDir);

  rutaDot := rutaDir + '/blockchain.dot';
  rutaPng := rutaDir + '/blockchain.png';

  GenerarReporteBlockchain(blockchainPtr^, rutaDot);
  WriteLn('🔗 DOT generado en: ', rutaDot);

  // Intentar generar PNG con dot si está disponible
  if ExecuteProcess('/bin/sh', ['-c', 'command -v dot >/dev/null 2>&1'], []) = 0 then
  begin
    if ExecuteProcess('/bin/sh', ['-c', 'dot -Tpng "' + rutaDot + '" -o "' + rutaPng + '"'], []) = 0 then
      WriteLn('🖼️ PNG generado en: ', rutaPng)
    else
      WriteLn('⚠️ No se pudo generar PNG con dot');
  end
  else
    WriteLn('ℹ️ Graphviz no está instalado; se dejó el .dot');
    
  gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_OK,
                        PChar('🔗 Reporte blockchain generado' + #10 + #10 +
                              'Archivos creados en /graficos/blockchain/'));
end;

procedure OnActualizarBlockchain(widget: PGtkWidget; data: gpointer); cdecl;
var
  blockchainPtr: ^TBlockchain;
begin
  blockchainPtr := PPointer(data)^;
  CargarBloquesEnLista(blockchainPtr^);
  
  // Actualizar información
  if LabelInfo <> nil then
    gtk_label_set_text(GTK_LABEL(LabelInfo), 
                      PChar('Total bloques: ' + IntToStr(blockchainPtr^.totalBloques) + 
                            ' | Dificultad: ' + IntToStr(blockchainPtr^.difficulty)));
  
  // Limpiar detalle
  if TextViewDetalle <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 
                             'Selecciona un bloque para ver detalles', -1);
end;

procedure OnCerrarBlockchain(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(BlockchainWindow) then
    gtk_widget_destroy(BlockchainWindow);
end;

function OnDeleteEventBlockchain(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando visor blockchain...');
  if Assigned(BlockchainWindow) then
    gtk_widget_destroy(BlockchainWindow);
  Result := True;
end;

procedure MostrarBlockchainViewer(var blockchainMail: TBlockchain);
var
  hpaned, vboxIzq, vboxDer, scrolledLista, scrolledDetalle: PGtkWidget;
  lblTitulo, lblDetalle: PGtkWidget;
  btnValidar, btnReporte, btnConsola, btnActualizar, btnCerrar, btnBox: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  blockchainPtr: Pointer;
begin
  WriteLn('🔗 Abriendo visor de blockchain...');
  
  if Assigned(BlockchainWindow) then
    gtk_widget_destroy(BlockchainWindow);
  
  BlockchainWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(BlockchainWindow), '🔗 Blockchain EDD-Mail Viewer');
  gtk_window_set_default_size(GTK_WINDOW(BlockchainWindow), 1400, 800);
  
  // Preparar puntero para callbacks
  blockchainPtr := @blockchainMail;
  g_signal_connect(BlockchainWindow, 'delete-event', G_CALLBACK(@OnDeleteEventBlockchain), blockchainPtr);
  
  hpaned := gtk_hpaned_new();
  gtk_container_add(GTK_CONTAINER(BlockchainWindow), hpaned);
  
  // Panel izquierdo - Lista de bloques
  vboxIzq := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxIzq), 10);
  gtk_paned_add1(GTK_PANED(hpaned), vboxIzq);
  
  lblTitulo := gtk_label_new('🔗 Blockchain de Correos (Lista Enlazada con Inserción al Inicio)');
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblTitulo, False, False, 0);
  
  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxIzq), scrolledLista, True, True, 0);
  
  store := gtk_list_store_new(7, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, 
                              G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaBloques := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaBloques);
  
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('INDEX', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 60);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBloques), column);
  
  column := gtk_tree_view_column_new_with_attributes('TIMESTAMP', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 140);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBloques), column);
  
  column := gtk_tree_view_column_new_with_attributes('DE', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBloques), column);
  
  column := gtk_tree_view_column_new_with_attributes('PARA', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBloques), column);
  
  column := gtk_tree_view_column_new_with_attributes('ASUNTO', renderer, 'text', 4, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBloques), column);
  
  column := gtk_tree_view_column_new_with_attributes('HASH', renderer, 'text', 5, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBloques), column);
  
  column := gtk_tree_view_column_new_with_attributes('NONCE', renderer, 'text', 6, nil);
  gtk_tree_view_column_set_min_width(column, 80);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaBloques), column);
  
  g_signal_connect(gtk_tree_view_get_selection(PGtkTreeView(ListaBloques)), 
                   'changed', G_CALLBACK(@OnSeleccionarBloque), blockchainPtr);
  
  // Botones de acción
  btnBox := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox, False, False, 0);
  
  btnActualizar := gtk_button_new_with_label('🔄 Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarBlockchain), blockchainPtr);
  gtk_box_pack_start(GTK_BOX(btnBox), btnActualizar, True, True, 0);
  
  btnValidar := gtk_button_new_with_label('🔍 Validar');
  g_signal_connect(btnValidar, 'clicked', G_CALLBACK(@OnValidarBlockchain), blockchainPtr);
  gtk_box_pack_start(GTK_BOX(btnBox), btnValidar, True, True, 0);
  
  btnReporte := gtk_button_new_with_label('📊 Reporte');
  g_signal_connect(btnReporte, 'clicked', G_CALLBACK(@OnGenerarReporteBlockchain), blockchainPtr);
  gtk_box_pack_start(GTK_BOX(btnBox), btnReporte, True, True, 0);
  
  btnConsola := gtk_button_new_with_label('📋 Consola');
  g_signal_connect(btnConsola, 'clicked', G_CALLBACK(@OnMostrarBlockchainConsola), blockchainPtr);
  gtk_box_pack_start(GTK_BOX(btnBox), btnConsola, True, True, 0);
  
  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarBlockchain), blockchainPtr);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, True, True, 0);
  
  LabelInfo := gtk_label_new('');
  gtk_box_pack_start(GTK_BOX(vboxIzq), LabelInfo, False, False, 0);
  
  // Panel derecho - Detalle del bloque
  vboxDer := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxDer), 10);
  gtk_paned_add2(GTK_PANED(hpaned), vboxDer);
  
  lblDetalle := gtk_label_new('Detalle del bloque:');
  gtk_box_pack_start(GTK_BOX(vboxDer), lblDetalle, False, False, 0);
  
  scrolledDetalle := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDetalle), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxDer), scrolledDetalle, True, True, 0);
  
  TextViewDetalle := gtk_text_view_new();
  gtk_text_view_set_editable(PGtkTextView(TextViewDetalle), False);
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDetalle), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDetalle), TextViewDetalle);
  
  // Mensaje inicial
  gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 
    '🔗 BLOCKCHAIN EDD-MAIL' + #13#10 + #13#10 +
    'Esta blockchain registra todos los correos enviados en el sistema.' + #13#10 + #13#10 +
    'Características:' + #13#10 +
    '• Lista enlazada con inserción al inicio' + #13#10 +
    '• Cada bloque contiene datos de un correo' + #13#10 +
    '• Hashing SHA-256' + #13#10 +
    '• Proof of Work con NONCE' + #13#10 +
    '• Enlaces PREVIOUS HASH para integridad' + #13#10 + #13#10 +
    'Selecciona un bloque para ver detalles completos.', -1);
  
  CargarBloquesEnLista(blockchainMail);
  
  // Actualizar información inicial
  gtk_label_set_text(GTK_LABEL(LabelInfo), 
                    PChar('Total bloques: ' + IntToStr(blockchainMail.totalBloques) + 
                          ' | Dificultad: ' + IntToStr(blockchainMail.difficulty)));
  
  gtk_widget_show_all(BlockchainWindow);
end;

end.
