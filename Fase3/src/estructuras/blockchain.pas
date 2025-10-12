unit blockchain;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DateUtils;

type
  // Estructura de datos del correo en el bloque
  TCorreoData = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
  end;

  // Estructura de un bloque
  PBloque = ^TBloque;
  TBloque = record
    index: Integer;
    timestamp: String;
    data: TCorreoData;
    nonce: Integer;
    previousHash: String;
    hash: String;
    siguiente: PBloque; // Para lista enlazada (inserción al inicio)
  end;

  // Estructura de la blockchain
  TBlockchain = record
    cabeza: PBloque;     // Último bloque insertado (más reciente)
    totalBloques: Integer;
    difficulty: Integer; // Dificultad para proof-of-work (cantidad de ceros iniciales)
  end;

// Funciones principales de blockchain
procedure InicializarBlockchain(var blockchain: TBlockchain);
procedure CrearBloqueGenesis(var blockchain: TBlockchain);
function CrearNuevoBloque(var blockchain: TBlockchain; const correoData: TCorreoData): PBloque;
procedure InsertarBloque(var blockchain: TBlockchain; const correoData: TCorreoData);
procedure MostrarBlockchain(var blockchain: TBlockchain);
procedure LiberarBlockchain(var blockchain: TBlockchain);

// Funciones de hashing y proof-of-work
function CalcularHash(index: Integer; const timestamp, data, previousHash: String; nonce: Integer): String;
function CalcularHashData(const correoData: TCorreoData): String;
function ProofOfWork(index: Integer; const timestamp, data, previousHash: String; difficulty: Integer): Integer;
function ValidarBloque(bloque: PBloque; previousHash: String; difficulty: Integer): Boolean;
function ValidarBlockchain(var blockchain: TBlockchain): Boolean;

// Funciones de utilidad
function ObtenerTimestamp(): String;
procedure RegistrarCorreoEnBlockchain(var blockchain: TBlockchain; correoID: Integer; const remitente, destinatario, asunto, mensaje: String);
function ContarBloquesBlockchain(var blockchain: TBlockchain): Integer;
procedure GenerarReporteBlockchain(var blockchain: TBlockchain; const rutaDot: String);

// Funciones de búsqueda
function BuscarCorreoEnBlockchain(var blockchain: TBlockchain; correoID: Integer): PBloque;
procedure ListarCorreosPorRemitente(var blockchain: TBlockchain; const remitente: String);

implementation

// Función simple de hash (simulando SHA-256 con un algoritmo básico pero funcional)
function HashSimple(const input: String): String;
var
  i, hash, a, b, c: Integer;
  resultado: String;
begin
  hash := 5381; // Constante inicial del algoritmo DJB2
  
  // Procesar cada carácter
  for i := 1 to Length(input) do
  begin
    hash := ((hash shl 5) + hash) + Ord(input[i]); // hash * 33 + c
    hash := hash and $7FFFFFFF; // Mantener positivo
  end;
  
  // Generar más complejidad mezclando con posiciones
  a := hash;
  b := 0;
  for i := 1 to Length(input) do
  begin
    b := b + (Ord(input[i]) * i);
  end;
  c := a xor b;
  
  // Convertir a hexadecimal de 64 caracteres (simulando SHA-256)
  resultado := IntToHex(a, 8) + IntToHex(b, 8) + IntToHex(c, 8) + IntToHex(hash xor a, 8);
  
  // Extender a 64 caracteres
  while Length(resultado) < 64 do
    resultado := resultado + IntToHex((hash + Length(resultado)) and $FF, 2);
  
  Result := LowerCase(Copy(resultado, 1, 64));
end;

// Inicializar blockchain vacía
procedure InicializarBlockchain(var blockchain: TBlockchain);
begin
  blockchain.cabeza := nil;
  blockchain.totalBloques := 0;
  blockchain.difficulty := 4; // Requiere 4 ceros al inicio del hash
  
  // Crear bloque génesis
  CrearBloqueGenesis(blockchain);
  
  WriteLn('🔗 Blockchain inicializada con bloque génesis');
end;

// Crear el bloque génesis (primer bloque de la cadena)
procedure CrearBloqueGenesis(var blockchain: TBlockchain);
var
  genesis: PBloque;
  genesisData: TCorreoData;
begin
  New(genesis);
  
  // Datos del bloque génesis
  genesis^.index := 0;
  genesis^.timestamp := ObtenerTimestamp();
  
  // Data especial para génesis
  genesisData.id := 0;
  genesisData.remitente := 'SISTEMA';
  genesisData.destinatario := 'GENESIS';
  genesisData.asunto := 'Bloque Genesis';
  genesisData.mensaje := 'Primer bloque de la blockchain EDD-Mail';
  genesis^.data := genesisData;
  
  genesis^.previousHash := '0000'; // Hash anterior del génesis es 0000
  genesis^.nonce := ProofOfWork(genesis^.index, genesis^.timestamp, 
                                CalcularHashData(genesis^.data), 
                                genesis^.previousHash, blockchain.difficulty);
  genesis^.hash := CalcularHash(genesis^.index, genesis^.timestamp, 
                               CalcularHashData(genesis^.data), 
                               genesis^.previousHash, genesis^.nonce);
  genesis^.siguiente := nil;
  
  // Insertar como cabeza
  blockchain.cabeza := genesis;
  blockchain.totalBloques := 1;
  
  WriteLn('🔗 Bloque génesis creado - Hash: ', Copy(genesis^.hash, 1, 16), '...');
end;

// Obtener timestamp actual en formato DD-MM-YY::HH:MM:SS
function ObtenerTimestamp(): String;
var
  ahora: TDateTime;
begin
  ahora := Now;
  Result := FormatDateTime('dd-mm-yy::hh:nn:ss', ahora);
end;

// Calcular hash de los datos del correo
function CalcularHashData(const correoData: TCorreoData): String;
var
  dataString: String;
begin
  dataString := IntToStr(correoData.id) + correoData.remitente + 
                correoData.destinatario + correoData.asunto + correoData.mensaje;
  Result := dataString;
end;

// Calcular hash del bloque usando nuestro algoritmo simple
function CalcularHash(index: Integer; const timestamp, data, previousHash: String; nonce: Integer): String;
var
  input: String;
begin
  // Concatenar todos los elementos sin espacios ni saltos de línea
  input := IntToStr(index) + timestamp + data + IntToStr(nonce) + previousHash;
  
  // Usar nuestro algoritmo de hash simple
  Result := HashSimple(input);
end;

// Proof of Work - encontrar nonce que produzca un hash con la dificultad requerida
function ProofOfWork(index: Integer; const timestamp, data, previousHash: String; difficulty: Integer): Integer;
var
  nonce: Integer;
  hash: String;
  target: String;
  i: Integer;
begin
  // Crear string target con zeros según dificultad
  target := '';
  for i := 1 to difficulty do
    target := target + '0';
  
  nonce := 0;
  repeat
    hash := CalcularHash(index, timestamp, data, previousHash, nonce);
    if Copy(hash, 1, difficulty) = target then
      Break;
    Inc(nonce);
    
    // Debug cada 1000 intentos para no saturar la consola
    if (nonce mod 1000) = 0 then
      WriteLn('⛏️ Minando bloque ', index, ' - Nonce: ', nonce, ' Hash: ', Copy(hash, 1, 16), '...');
      
  until False;
  
  WriteLn('✅ Proof of Work completado - Nonce: ', nonce, ' Hash: ', Copy(hash, 1, 16), '...');
  Result := nonce;
end;

// Crear nuevo bloque con datos de correo
function CrearNuevoBloque(var blockchain: TBlockchain; const correoData: TCorreoData): PBloque;
var
  nuevoBloque: PBloque;
  previousHash: String;
begin
  New(nuevoBloque);
  
  // Obtener hash del bloque anterior
  if blockchain.cabeza <> nil then
    previousHash := blockchain.cabeza^.hash
  else
    previousHash := '0000';
  
  // Configurar bloque
  nuevoBloque^.index := blockchain.totalBloques;
  nuevoBloque^.timestamp := ObtenerTimestamp();
  nuevoBloque^.data := correoData;
  nuevoBloque^.previousHash := previousHash;
  
  // Calcular proof of work
  WriteLn('⛏️ Iniciando minado para bloque ', nuevoBloque^.index);
  nuevoBloque^.nonce := ProofOfWork(nuevoBloque^.index, nuevoBloque^.timestamp,
                                   CalcularHashData(nuevoBloque^.data),
                                   nuevoBloque^.previousHash, blockchain.difficulty);
  
  // Calcular hash final
  nuevoBloque^.hash := CalcularHash(nuevoBloque^.index, nuevoBloque^.timestamp,
                                   CalcularHashData(nuevoBloque^.data),
                                   nuevoBloque^.previousHash, nuevoBloque^.nonce);
  
  nuevoBloque^.siguiente := nil;
  
  Result := nuevoBloque;
end;

// Insertar bloque al inicio de la cadena (lista enlazada)
procedure InsertarBloque(var blockchain: TBlockchain; const correoData: TCorreoData);
var
  nuevoBloque: PBloque;
begin
  WriteLn('🔗 Creando nuevo bloque para correo ID: ', correoData.id);
  
  nuevoBloque := CrearNuevoBloque(blockchain, correoData);
  
  // Insertar al inicio (la cabeza apunta al bloque más reciente)
  nuevoBloque^.siguiente := blockchain.cabeza;
  blockchain.cabeza := nuevoBloque;
  Inc(blockchain.totalBloques);
  
  WriteLn('✅ Bloque ', nuevoBloque^.index, ' insertado en blockchain');
  WriteLn('   Hash: ', Copy(nuevoBloque^.hash, 1, 32), '...');
  WriteLn('   Correo: ', correoData.remitente, ' -> ', correoData.destinatario);
end;

// Registrar correo en blockchain (función principal para integración)
procedure RegistrarCorreoEnBlockchain(var blockchain: TBlockchain; correoID: Integer; const remitente, destinatario, asunto, mensaje: String);
var
  correoData: TCorreoData;
begin
  // Preparar datos del correo
  correoData.id := correoID;
  correoData.remitente := remitente;
  correoData.destinatario := destinatario;
  correoData.asunto := asunto;
  correoData.mensaje := mensaje;
  
  // Insertar en blockchain
  InsertarBloque(blockchain, correoData);
end;

// Validar un bloque individual
function ValidarBloque(bloque: PBloque; previousHash: String; difficulty: Integer): Boolean;
var
  hashCalculado: String;
  target: String;
  i: Integer;
begin
  Result := False;
  
  // Verificar previous hash
  if bloque^.previousHash <> previousHash then
    Exit;
  
  // Recalcular hash
  hashCalculado := CalcularHash(bloque^.index, bloque^.timestamp,
                               CalcularHashData(bloque^.data),
                               bloque^.previousHash, bloque^.nonce);
  
  // Verificar que el hash coincide
  if hashCalculado <> bloque^.hash then
    Exit;
  
  // Verificar proof of work (dificultad)
  target := '';
  for i := 1 to difficulty do
    target := target + '0';
  
  if Copy(bloque^.hash, 1, difficulty) <> target then
    Exit;
  
  Result := True;
end;

// Validar toda la blockchain
function ValidarBlockchain(var blockchain: TBlockchain): Boolean;
var
  actual: PBloque;
  expectedPreviousHash: String;
begin
  Result := False;
  
  if blockchain.cabeza = nil then
    Exit;
  
  // Recorrer desde el más reciente al más antiguo
  actual := blockchain.cabeza;
  expectedPreviousHash := '';
  
  while actual <> nil do
  begin
    // Para el primer bloque (más reciente), obtener el hash que debería tener el anterior
    if actual = blockchain.cabeza then
    begin
      if actual^.siguiente <> nil then
        expectedPreviousHash := actual^.siguiente^.hash
      else
        expectedPreviousHash := '0000'; // Génesis
    end;
    
    // Validar bloque actual
    if not ValidarBloque(actual, expectedPreviousHash, blockchain.difficulty) then
    begin
      WriteLn('❌ Bloque ', actual^.index, ' es inválido');
      Exit;
    end;
    
    // Preparar para siguiente iteración
    expectedPreviousHash := actual^.hash;
    actual := actual^.siguiente;
  end;
  
  Result := True;
  WriteLn('✅ Blockchain válida');
end;

// Mostrar toda la blockchain
procedure MostrarBlockchain(var blockchain: TBlockchain);
var
  actual: PBloque;
  contador: Integer;
begin
  WriteLn('🔗 BLOCKCHAIN EDD-MAIL');
  WriteLn('=====================');
  WriteLn('Total de bloques: ', blockchain.totalBloques);
  WriteLn('Dificultad: ', blockchain.difficulty);
  WriteLn('');
  
  contador := 0;
  actual := blockchain.cabeza;
  
  while actual <> nil do
  begin
    Inc(contador);
    WriteLn('📦 BLOQUE #', actual^.index, ' (Posición en cadena: ', contador, ')');
    WriteLn('   Timestamp: ', actual^.timestamp);
    WriteLn('   Datos del correo:');
    WriteLn('     - ID: ', actual^.data.id);
    WriteLn('     - De: ', actual^.data.remitente);
    WriteLn('     - Para: ', actual^.data.destinatario);
    WriteLn('     - Asunto: ', actual^.data.asunto);
    WriteLn('     - Mensaje: ', Copy(actual^.data.mensaje, 1, 50), '...');
    WriteLn('   Nonce: ', actual^.nonce);
    WriteLn('   Previous Hash: ', Copy(actual^.previousHash, 1, 16), '...');
    WriteLn('   Hash: ', Copy(actual^.hash, 1, 32), '...');
    WriteLn('   ----------------------------------------');
    
    actual := actual^.siguiente;
  end;
  
  WriteLn('=====================');
end;

// Contar bloques en blockchain
function ContarBloquesBlockchain(var blockchain: TBlockchain): Integer;
begin
  Result := blockchain.totalBloques;
end;

// Buscar correo por ID en blockchain
function BuscarCorreoEnBlockchain(var blockchain: TBlockchain; correoID: Integer): PBloque;
var
  actual: PBloque;
begin
  Result := nil;
  actual := blockchain.cabeza;
  
  while actual <> nil do
  begin
    if actual^.data.id = correoID then
    begin
      Result := actual;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

// Listar correos por remitente
procedure ListarCorreosPorRemitente(var blockchain: TBlockchain; const remitente: String);
var
  actual: PBloque;
  encontrados: Integer;
begin
  WriteLn('🔍 Buscando correos de: ', remitente);
  encontrados := 0;
  actual := blockchain.cabeza;
  
  while actual <> nil do
  begin
    if LowerCase(actual^.data.remitente) = LowerCase(remitente) then
    begin
      Inc(encontrados);
      WriteLn('  📧 Bloque #', actual^.index, ' - Para: ', actual^.data.destinatario, 
              ' - Asunto: ', actual^.data.asunto);
    end;
    actual := actual^.siguiente;
  end;
  
  WriteLn('Total encontrados: ', encontrados);
end;

// Generar reporte DOT de blockchain
procedure GenerarReporteBlockchain(var blockchain: TBlockchain; const rutaDot: String);
var
  f: Text;
  actual: PBloque;
  contador: Integer;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph Blockchain {');
    WriteLn(f, '  rankdir=LR;');
    WriteLn(f, '  node [shape=record, style=filled, fontname="Arial", fontsize=10];');
    WriteLn(f, '  edge [color="#4F81BD", penwidth=2];');
    WriteLn(f, '  label="🔗 BLOCKCHAIN EDD-MAIL\\nTotal Bloques: ', blockchain.totalBloques, 
            ' | Dificultad: ', blockchain.difficulty, '"; labelloc=t; fontsize=14; fontcolor=blue;');
    WriteLn(f, '');
    
    contador := 0;
    actual := blockchain.cabeza;
    
    // Recorrer blockchain del más reciente al más antiguo
    while actual <> nil do
    begin
      Inc(contador);
      
      // Color según tipo de bloque
      if actual^.index = 0 then
        WriteLn(f, '  bloque_', actual^.index, ' [label="🔗 GÉNESIS\\nIndex: ', actual^.index, 
                '\\nTime: ', actual^.timestamp, '\\nHash: ', Copy(actual^.hash, 1, 16), 
                '...\\nNonce: ', actual^.nonce, '", fillcolor="#FFD700"];')
      else
        WriteLn(f, '  bloque_', actual^.index, ' [label="📦 BLOQUE ', actual^.index, 
                '\\nCorreo ID: ', actual^.data.id, '\\nDe: ', Copy(actual^.data.remitente, 1, 15),
                '\\nPara: ', Copy(actual^.data.destinatario, 1, 15), '\\nTime: ', actual^.timestamp,
                '\\nHash: ', Copy(actual^.hash, 1, 16), '...\\nNonce: ', actual^.nonce, 
                '", fillcolor="#E6F3FF"];');
      
      // Conexión al bloque anterior (siguiente en la lista)
      if actual^.siguiente <> nil then
        WriteLn(f, '  bloque_', actual^.index, ' -> bloque_', actual^.siguiente^.index, 
                ' [label="Previous\\nHash", fontsize=8];');
      
      actual := actual^.siguiente;
    end;
    
    // Agregar información adicional
    WriteLn(f, '');
    WriteLn(f, '  info [label="ℹ️ INFORMACIÓN\\nInserción: Al inicio\\nRecorrido: Más reciente → Más antiguo\\nValidación: Hash Simple + Proof of Work", shape=note, fillcolor="#FFFFCC"];');
    
    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
  
  WriteLn('🔗 Reporte blockchain generado: ', rutaDot);
end;

// Liberar memoria de blockchain
procedure LiberarBlockchain(var blockchain: TBlockchain);
var
  actual, temp: PBloque;
begin
  actual := blockchain.cabeza;
  while actual <> nil do
  begin
    temp := actual^.siguiente;
    Dispose(actual);
    actual := temp;
  end;
  
  blockchain.cabeza := nil;
  blockchain.totalBloques := 0;
end;

end.
