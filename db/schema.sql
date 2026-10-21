-- =====================================================================
--  Histórico Cubiscan · Esquema de base de datos (SQLite 3)
--  Origen: historico_cubiscan.html (bloque <script id="data">)
--  Ruta del archivo de base:  db/cubiscan.db
--  Crear:   sqlite3 db/cubiscan.db < db/schema.sql
--  Cargar:  sqlite3 db/cubiscan.db < db/data.sql
-- =====================================================================
PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
--  CATÁLOGOS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS empaque (
    id      INTEGER PRIMARY KEY,
    codigo  TEXT NOT NULL UNIQUE                 -- PA, CS, EA, IP
);

CREATE TABLE IF NOT EXISTS turno (
    id      INTEGER PRIMARY KEY,
    codigo  TEXT NOT NULL UNIQUE CHECK (codigo IN ('AM','PM'))
);

CREATE TABLE IF NOT EXISTS operador (
    id      INTEGER PRIMARY KEY,
    codigo  TEXT NOT NULL UNIQUE                 -- CF, MO, KC, MA, CG/KC, CG, KG
);

CREATE TABLE IF NOT EXISTS proceso (
    id      INTEGER PRIMARY KEY,
    nombre  TEXT NOT NULL UNIQUE                 -- Cubiscan, Corrección, Sobredimensionado, VAS, ...
);

CREATE TABLE IF NOT EXISTS tipo_bloqueo (
    id           INTEGER PRIMARY KEY,
    descripcion  TEXT NOT NULL UNIQUE            -- causa de la incidencia
);

CREATE TABLE IF NOT EXISTS observacion (
    id     INTEGER PRIMARY KEY,
    texto  TEXT NOT NULL UNIQUE                  -- observaciones generales
);

CREATE TABLE IF NOT EXISTS nota (
    id     INTEGER PRIMARY KEY,
    texto  TEXT NOT NULL UNIQUE                  -- AGOTAR STOCK, AGOTAR ANTERIOR, NUEVO FP
);

CREATE TABLE IF NOT EXISTS sku (
    id      INTEGER PRIMARY KEY,
    codigo  TEXT NOT NULL UNIQUE
);

-- EAN / DUN como texto: hay códigos alfanuméricos y con ceros a la izquierda
CREATE TABLE IF NOT EXISTS ean (
    id      INTEGER PRIMARY KEY,
    codigo  TEXT NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
--  TABLA PRINCIPAL: una fila por medición Cubiscan
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS medicion (
    id               INTEGER PRIMARY KEY,
    ean_id           INTEGER REFERENCES ean(id),
    sku_id           INTEGER NOT NULL REFERENCES sku(id),
    unidades         REAL CHECK (unidades  IS NULL OR unidades  >= 0),
    largo_cm         REAL CHECK (largo_cm  IS NULL OR largo_cm  >= 0),
    alto_cm          REAL CHECK (alto_cm   IS NULL OR alto_cm   >= 0),
    ancho_cm         REAL CHECK (ancho_cm  IS NULL OR ancho_cm  >= 0),
    peso_kg          REAL CHECK (peso_kg   IS NULL OR peso_kg   >= 0),
    empaque_id       INTEGER REFERENCES empaque(id),
    fecha            TEXT NOT NULL,              -- ISO 'YYYY-MM-DD'
    turno_id         INTEGER REFERENCES turno(id),
    operador_id      INTEGER REFERENCES operador(id),
    proceso_id       INTEGER REFERENCES proceso(id),
    requiere_vas     TEXT CHECK (requiere_vas  IN ('SI','NO')),
    vas_realizado    TEXT CHECK (vas_realizado IN ('SI','NO')),
    asn              TEXT,
    bloqueo          TEXT CHECK (bloqueo IN ('SI','NO','VAS')),
    tipo_bloqueo_id  INTEGER REFERENCES tipo_bloqueo(id),
    ley_rep          TEXT CHECK (ley_rep IN ('SI','NO')),
    observacion_id   INTEGER REFERENCES observacion(id),
    nota_id          INTEGER REFERENCES nota(id),
    origen           TEXT NOT NULL DEFAULT 'historico'
                     CHECK (origen IN ('historico','ingresado')),
    creado_en        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS ix_medicion_sku      ON medicion(sku_id);
CREATE INDEX IF NOT EXISTS ix_medicion_ean      ON medicion(ean_id);
CREATE INDEX IF NOT EXISTS ix_medicion_fecha    ON medicion(fecha);
CREATE INDEX IF NOT EXISTS ix_medicion_asn      ON medicion(asn);
CREATE INDEX IF NOT EXISTS ix_medicion_operador ON medicion(operador_id);
CREATE INDEX IF NOT EXISTS ix_medicion_bloqueo  ON medicion(bloqueo, tipo_bloqueo_id);

-- ---------------------------------------------------------------------
--  REPORTES DE INCIDENCIA (historial que el panel guardaba en el navegador)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reporte_incidencia (
    id             INTEGER PRIMARY KEY,
    numero         TEXT NOT NULL UNIQUE,
    fecha          TEXT NOT NULL,
    sku            TEXT,
    asn            TEXT,
    turno          TEXT,
    operador       TEXT,
    tipo           TEXT,
    severidad      TEXT NOT NULL DEFAULT 'Media'
                   CHECK (severidad IN ('Baja','Media','Alta','Crítica')),
    bloqueo        TEXT,
    vas            TEXT,
    descripcion    TEXT,
    accion         TEXT,
    destinatario   TEXT,
    autor          TEXT,
    area           TEXT DEFAULT 'Control de calidad · Cubiscan',
    creado_en      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS reporte_foto (
    id          INTEGER PRIMARY KEY,
    reporte_id  INTEGER NOT NULL REFERENCES reporte_incidencia(id) ON DELETE CASCADE,
    nombre      TEXT,
    data        BLOB NOT NULL,                   -- imagen (o data-URL base64)
    ancho_px    INTEGER,
    alto_px     INTEGER,
    kb          REAL
);
CREATE INDEX IF NOT EXISTS ix_foto_reporte ON reporte_foto(reporte_id);

-- ---------------------------------------------------------------------
--  METADATOS DE LA CARGA (fecha base, resumen de calidad de datos)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meta (
    clave  TEXT PRIMARY KEY,
    valor  TEXT
);

-- ---------------------------------------------------------------------
--  VISTAS
-- ---------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS v_medicion AS
SELECT m.id,
       e.codigo  AS ean,
       s.codigo  AS sku,
       n.texto   AS nota,
       m.unidades, m.largo_cm, m.alto_cm, m.ancho_cm, m.peso_kg,
       ROUND(m.largo_cm * m.alto_cm * m.ancho_cm / 1000000.0, 6) AS volumen_m3,
       em.codigo AS empaque,
       m.fecha,
       t.codigo  AS turno,
       o.codigo  AS operador,
       p.nombre  AS proceso,
       m.requiere_vas, m.vas_realizado, m.asn, m.bloqueo,
       tb.descripcion AS tipo_bloqueo,
       m.ley_rep,
       ob.texto  AS observacion,
       m.origen
FROM medicion m
JOIN sku s               ON s.id  = m.sku_id
LEFT JOIN ean e          ON e.id  = m.ean_id
LEFT JOIN nota n         ON n.id  = m.nota_id
LEFT JOIN empaque em     ON em.id = m.empaque_id
LEFT JOIN turno t        ON t.id  = m.turno_id
LEFT JOIN operador o     ON o.id  = m.operador_id
LEFT JOIN proceso p      ON p.id  = m.proceso_id
LEFT JOIN tipo_bloqueo tb ON tb.id = m.tipo_bloqueo_id
LEFT JOIN observacion ob ON ob.id = m.observacion_id;

-- Incidencias: mediciones con bloqueo o con causa registrada
CREATE VIEW IF NOT EXISTS v_incidencia AS
SELECT * FROM v_medicion
WHERE bloqueo IN ('SI','VAS') OR tipo_bloqueo IS NOT NULL;

-- Última medición por SKU + empaque (ficha vigente)
CREATE VIEW IF NOT EXISTS v_ultima_medicion AS
SELECT * FROM v_medicion v
WHERE v.id = (SELECT m2.id FROM medicion m2
              JOIN sku s2 ON s2.id = m2.sku_id
              LEFT JOIN empaque e2 ON e2.id = m2.empaque_id
              WHERE s2.codigo = v.sku AND e2.codigo IS v.empaque
              ORDER BY m2.fecha DESC, m2.id DESC LIMIT 1);
