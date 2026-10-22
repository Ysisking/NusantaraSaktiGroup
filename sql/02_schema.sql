-- Cek semua tabel yang ada di database
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT *
FROM [tbl_cabang master];

SELECT TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
	AND TABLE_NAME != 'sysdiagrams'
ORDER BY TABLE_NAME;

SELECT t.NAME AS TableName, p.rows AS RowsCounts
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id IN (0,1)
ORDER BY p.rows DESC;

SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, (IS_NULLABLE)
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT
	COUNT (*)                         AS total_baris,
	COUNT (*) - COUNT (id_penjualan)  AS null_id_penjualan,
	COUNT (*) - COUNT (id_cabang)	  AS null_id_cabang,
	COUNT (*) - COUNT (tgl_transaksi) AS null_tgl_transaksi,
	COUNT (*) - COUNT (harga_otr)     AS null_harga_otr,
	COUNT (*) - COUNT (metode_bayar)  AS null_metode_bayar,
	COUNT (*) - COUNT (tgl_do)        AS null_tgl_do
FROM tbl_penjualan_unit;

SELECT id_penjualan, COUNT(*) AS n
FROM tbl_penjualan_unit
GROUP BY id_penjualan
HAVING COUNT(*) > 1;

-- Cleaning tbl penjualan unit
SELECT tgl_transaksi
FROM tbl_penjualan_unit
WHERE TRY_CAST (tgl_transaksi AS DATE) IS NULL
	AND tgl_transaksi IS NOT NULL;

UPDATE tbl_penjualan_unit
SET tgl_transaksi = CONVERT(NVARCHAR(10),
						CONVERT(DATE,tgl_transaksi,101), 23)
WHERE tgl_transaksi LIKE '__/__/____';

SELECT harga_otr 
FROM tbl_penjualan_unit
WHERE TRY_CAST(REPLACE(harga_otr,'.','') AS BIGINT) IS NOT NULL
	AND harga_otr LIKE '%.%.%';

UPDATE tbl_penjualan_unit
SET harga_otr = REPLACE(CAST(harga_otr AS NVARCHAR), '.','')
WHERE CAST(harga_otr AS NVARCHAR) LIKE '%.%.%';

ALTER TABLE tbl_penjualan_unit
ADD flag_do_anomali BIT DEFAULT 0;
GO

UPDATE tbl_penjualan_unit
SET flag_do_anomali = 1
WHERE status_do = 'Selesai' AND tgl_do IS NULL;

-- Cleaning tbl leads prospek

UPDATE tbl_leads_prospek
SET status_leads = 'Closing'
WHERE UPPER(LTRIM(RTRIM(status_leads)))
		IN ('CLOSING', 'CLOSED', 'DEAL', 'CLOSE');

UPDATE tbl_leads_prospek
SET status_leads = 'Follow Up'
WHERE UPPER(LTRIM(RTRIM(status_leads)))
		IN('FOLLOW UP', 'FOLLOWUP', 'FU');

ALTER TABLE tbl_leads_prospek
ADD flag_hp_invalid BIT DEFAULT 0;

UPDATE tbl_leads_prospek
SET flag_hp_invalid = 1
WHERE LEN(no_hp) < 10
	OR no_hp LIKE '%x%'
	OR no_hp LIKE '%-%'
	OR no_hp LIKE '+62%'
	OR no_hp = '';

ALTER TABLE tbl_leads_prospek
ADD flag_closing_kontradiksi BIT DEFAULT 0;
GO
UPDATE tbl_leads_prospek
SET flag_closing_kontradiksi = 1
WHERE tgl_closing IS NOT NULL
	AND status_leads != 'Closing';

-- Cleaning tbl kredit pengajuan

UPDATE tbl_kredit_pengajuan
SET tenor_bulan = REPLACE(REPLACE(tenor_bulan, ' bulan', ''), 'bulan', '')
WHERE tenor_bulan LIKE '%bulan%';

ALTER TABLE tbl_kredit_pengajuan
ALTER COLUMN tenor_bulan INT;

ALTER TABLE tbl_kredit_pengajuan
ADD flag_penghasilan_anomali BIT DEFAULT 0;
UPDATE tbl_kredit_pengajuan
SET flag_penghasilan_anomali = 1
WHERE penghasilan_bulanan <= 0
	OR penghasilan_bulanan > 50000000;

UPDATE tbl_kredit_pengajuan
SET status_kredit = 'Approved'
WHERE UPPER(LTRIM(RTRIM(status_kredit)))
	IN ('APPROVED', 'APPROVE', 'ACC', 'ACCEPT');
UPDATE tbl_kredit_pengajuan
SET status_kredit = 'Rejected'
WHERE UPPER(LTRIM(RTRIM(status_kredit)))
	IN ('REJECTED', 'REJECT', 'TOLAK');

-- Cleaning kredit cicilan

UPDATE tbl_kredit_cicilan
SET status_bayar = 'Lunas'
WHERE UPPER(LTRIM(RTRIM(status_bayar)))
		IN ('LUNAS', 'L', 'PAID', 'BAYAR');
UPDATE tbl_kredit_cicilan
SET status_bayar = 'Menunggak'
WHERE UPPER(LTRIM(RTRIM(status_bayar)))
		IN ('MENUNGGAK', 'NPL', 'MACET');

UPDATE tbl_kredit_cicilan
SET jumlah_cicilan = REPLACE(jumlah_cicilan, ' IDR', '')
WHERE CAST(jumlah_cicilan AS NVARCHAR) LIKE '% IDR';

ALTER TABLE tbl_kredit_cicilan
ALTER COLUMN jumlah_cicilan BIGINT;

UPDATE tbl_kredit_cicilan
SET hari_terlambat = 0
WHERE hari_terlambat < 0;

ALTER TABLE tbl_kredit_cicilan
ADD flag_npl BIT DEFAULT 0;
UPDATE tbl_kredit_cicilan
SET flag_npl = 1
WHERE status_bayar = 'Menunggak'
	OR hari_terlambat >30;

-- Cleanin Service Kunjungan
ALTER TABLE tbl_service_kunjungan
ADD flag_jam_anomali BIT DEFAULT 0;
UPDATE tbl_service_kunjungan
SET flag_jam_anomali = 1
WHERE TRY_CAST(jam_keluar AS TIME) < TRY_CAST(jam_masuk AS TIME)
	AND jam_keluar IS NOT NULL AND jam_masuk IS NOT NULL;

ALTER TABLE tbl_service_kunjungan
ADD flag_selesai_tanpa_jam BIT DEFAULT 0;
UPDATE tbl_service_kunjungan 
SET flag_selesai_tanpa_jam = 1
WHERE status_service = 'Selesai' AND jam_keluar IS NULL;

ALTER TABLE tbl_service_kunjungan
ADD durasi_menit INT;
UPDATE tbl_service_kunjungan
SET durasi_menit = DATEDIFF(MINUTE,
	TRY_CAST(jam_masuk AS TIME),
	TRY_CAST(jam_keluar AS TIME))
WHERE flag_jam_anomali = 0
	AND jam_keluar IS NOT NULL;

-- Cleaning Tbl Absensi Karyawan
UPDATE tbl_absensi_karyawan
SET status_kehadiran = 'Hadir'
WHERE UPPER(LTRIM(RTRIM(status_kehadiran)))
	IN('HADIR', 'H', '1', 'PRESENT', 'MASUK');
UPDATE tbl_absensi_karyawan
SET status_kehadiran = 'Alpha'
WHERE UPPER(LTRIM(RTRIM(status_kehadiran)))
	IN ('ALPHA', 'ALFA', 'A', 'TANPA KET');

UPDATE tbl_absensi_karyawan
SET divisi ='HR'
WHERE UPPER(divisi) IN ('HR', 'HRD', 'SDM');
UPDATE tbl_absensi_karyawan
SET divisi = 'Service'
WHERE UPPER (divisi) IN ('SERVICE', 'SERVIS', 'BENGKEL');
UPDATE tbl_absensi_karyawan
SET divisi = 'Finance'
WHERE UPPER (divisi) IN ('FINANCE', 'KEUANGAN','FINANCE & ACC');

ALTER TABLE tbl_absensi_karyawan
ADD flag_hadir_tanpa_jam BIT DEFAULT 0;
UPDATE tbl_absensi_karyawan
SET flag_hadir_tanpa_jam = 1
WHERE status_kehadiran = 'Hadir'
	AND jam_masuk IS NULL;

ALTER TABLE tbl_absensi_karyawan
ADD flag_terlambat BIT DEFAULT 0;
UPDATE tbl_absensi_karyawan
SET flag_terlambat = 1
WHERE status_kehadiran = 'Hadir'
	AND TRY_CAST(jam_masuk AS TIME) > '08:30';


-- MODELING
-- Start Schema
SELECT id_cabang, nama_cabang, kota, provinsi, status
INTO dim_cabang
FROM tbl_cabang_master
ALTER TABLE dim_cabang ADD PRIMARY KEY (id_cabang);

SELECT id_karyawan, nama_karyawan, id_cabang, divisi, jabatan, 
		gaji_pokok,status_karyawan, jenis_kelamin
INTO dim_karyawan
FROM tbl_karyawan_master
ALTER TABLE dim_karyawan ADD PRIMARY KEY (id_karyawan);

WITH cte_date AS (
	SELECT CAST('2024-01-01' AS DATE) AS tanggal
	UNION ALL
	SELECT DATEADD(DAY, 1,tanggal)
	FROM cte_date
	WHERE tanggal < '2024-03-31'
)
SELECT
	tanggal,
	MONTH(tanggal) AS bulan,
	DATENAME(MONTH, tanggal) AS nama_bulan,
	DATEPART(WEEK, tanggal) AS minggu,
	YEAR(tanggal) AS tahun,
	1 AS kuartal
INTO dim_tanggal
FROM cte_date
OPTION(MAXRECURSION 365);

ALTER TABLE dim_tanggal
ALTER COLUMN tanggal DATE NOT NULL;
GO
ALTER TABLE dim_tanggal
ADD PRIMARY KEY (tanggal);

SELECT DISTINCT tipe_motor, kategori_motor
INTO dim_motor
FROM tbl_penjualan_unit;
ALTER TABLE dim_motor
ADD id_motor INT IDENTITY(1,1) PRIMARY KEY;

SELECT
	p.id_penjualan,
	TRY_CAST(p.tgl_transaksi AS DATE) AS tanggal,
	p.id_cabang,
	p.id_sales,
	m.id_motor,
	p.harga_otr,
	p.metode_bayar,
	CASE WHEN p.metode_bayar = 'Kredit' THEN 1 ELSE 0 END AS is_kredit,
	p.channel_penjualan,
	p.status_do,
	p.flag_do_anomali
INTO fact_penjualan
FROM tbl_penjualan_unit p
LEFT JOIN dim_motor m ON p.tipe_motor = m.tipe_motor;

SELECT
	c.id_cicilan,
	c.id_kredit,
	c.id_cabang,
	TRY_CAST(c.tgl_jatuh_tempo AS DATE) AS tanggal_jatuh_tempo,
	TRY_CAST(c.tgl_bayar_actual AS DATE) AS tanggal_bayar,
	c.bulan_ke,
	c.jumlah_cicilan,
	c.denda_keterlambatan,
	c.status_bayar,
	c.hari_terlambat,
	c.flag_npl,
	k.tenor_bulan,
	k.pekerjaan,
	k.penghasilan_bulanan,
	k.lembaga_pembiayaan
INTO fact_kredit
FROM tbl_kredit_cicilan c
LEFT JOIN tbl_kredit_pengajuan k ON c.id_kredit = k.id_kredit;

ALTER TABLE tbl_service_kunjungan
ADD flag_csi_invalid BIT DEFAULT 0;
GO
UPDATE tbl_service_kunjungan
SET flag_csi_invalid = 1
WHERE csi_score < 1 
   OR csi_score > 5
   OR csi_score IS NULL;
GO
SELECT
	id_service,
	id_cabang,
	id_pelanggan,
	id_mekanik,
	TRY_CAST(tgl_service AS DATE) AS tanggal,
	durasi_menit,
	tipe_service,
	biaya_jasa,
	biaya_sparepart,
	total_biaya,
	CASE WHEN csi_score BETWEEN 1 AND 5
		 THEN csi_score ELSE NULL END AS csi_score,
	status_service,
	flag_jam_anomali,
	flag_csi_invalid
INTO fact_service
FROM tbl_service_kunjungan;

SELECT
	a.id_absensi,
	a.id_karyawan,
	a.id_cabang,
	a.divisi,
	TRY_CAST(a.tanggal AS DATE) AS tanggal,
	a.status_kehadiran,
	CASE WHEN a.status_kehadiran = 'Hadir' THEN 1 ELSE 0 END AS is_hadir,
	CASE WHEN a.status_kehadiran = 'Alpha' THEN 1 ELSE 0 END AS is_alpha,
	a.overtime_jam,
	a.flag_terlambat,
	a.flag_hadir_tanpa_jam,
	-- cost lembur = overtime x (gaji/173) x 1.5
	CASE WHEN a.overtime_jam > 0
		 THEN CAST(a.overtime_jam AS FLOAT)
			 * (k.gaji_pokok / 173.0) * 1.5
		 ELSE 0 END AS cost_lembur
	INTO fact_absensi
	FROM tbl_absensi_karyawan a
	LEFT JOIN dim_karyawan k ON a.id_karyawan = k.id_karyawan;

	-- .......................
	-- Cek jumlah baris keduanya
SELECT 'tbl_cabang_master' AS sumber, COUNT(*) AS baris
FROM tbl_cabang_master
UNION ALL
SELECT 'tbl_cabang master', COUNT(*)
FROM [tbl_cabang master];

DROP TABLE [tbl_cabang master];
-- ................................
SELECT *
FROM tbl_sales_target;
-- Analisis
-- cabang paling jauh dari target
WITH cte_aktual AS (
	SELECT id_cabang,
			COUNT(id_penjualan) AS unit_aktual,
			SUM(harga_otr)		AS revenue_aktual
	FROM fact_penjualan
	GROUP BY id_cabang
),
cte_target AS (
	SELECT id_cabang,
		SUM(target_unit)			AS total_target_unit,
		SUM(target_revenue)			AS total_target_revenue
	FROM tbl_sales_target
	WHERE tahun = 2024
	GROUP BY id_cabang
)
SELECT
	cb.nama_cabang,
	cb.provinsi,
	ISNULL(a.unit_aktual, 0)		 AS unit_aktual,
	ISNULL(t.total_target_unit, 0)	 AS target_unit,
	ISNULL(a.unit_aktual,0) 
	- ISNULL(t.total_target_unit, 0) AS gap_unit,
	CAST(ISNULL(a.unit_aktual,0) * 100.0
	/ NULLIF(t.total_target_unit,0)  AS DECIMAL(5,1)) AS achievement_pct
FROM dim_cabang cb
LEFT JOIN cte_aktual a ON cb.id_cabang = a.id_cabang
LEFT JOIN cte_target t ON cb.id_cabang = t.id_cabang
ORDER BY gap_unit ASC;

-- tipe motor paling laku per region
ALTER TABLE fact_penjualan
ALTER COLUMN harga_otr BIGINT;
GO
SELECT 
	cb.provinsi,
	m.tipe_motor,
	m.kategori_motor,
	COUNT(f.id_penjualan) AS unit_terjual,
	SUM(f.harga_otr)	  AS total_revenue
FROM fact_penjualan f
JOIN dim_cabang cb ON f.id_cabang = cb.id_cabang
JOIN dim_motor m ON f.id_motor = m.id_motor
GROUP BY cb.provinsi, m.tipe_motor, m.kategori_motor
ORDER BY cb.provinsi, unit_terjual DESC;

-- sales person dengan conversation rate leads tertinggi
WITH cte_leads AS (
	SELECT 
		id_sales,
		COUNT(*) AS total_leads,
		SUM(CASE WHEN status_leads = 'Closing'
				 THEN 1 ELSE 0 END) AS total_closing
	FROM tbl_leads_prospek
	GROUP BY id_sales
)
SELECT
	k.nama_karyawan,
	cb.nama_cabang,
	l.total_leads,
	l.total_closing,
	CAST(l.total_closing * 100.0
	/ NULLIF(l.total_leads,0) AS DECIMAL(5,1)) AS conversion_rate_pct
FROM cte_leads l
JOIN dim_karyawan k ON l.id_sales = k.id_karyawan
JOIN dim_cabang cb ON k.id_cabang = cb.id_cabang
ORDER BY conversion_rate_pct DESC;

-- Rata-rata waktu leads masuk hingga closing
SELECT
	cb.nama_cabang,
	COUNT(*) AS total_closing,
	AVG(DATEDIFF(DAY,
		TRY_CAST(tgl_masuk AS DATE),
		TRY_CAST(tgl_closing AS DATE))) AS avg_hari_closing,
	MIN(DATEDIFF(DAY,
		TRY_CAST(tgl_masuk AS DATE),
		TRY_CAST(tgl_closing AS DATE))) AS min_hari,
	MAX(DATEDIFF(DAY,
		TRY_CAST(tgl_masuk AS DATE),
		TRY_CAST(tgl_closing AS DATE))) AS max_hari
FROM tbl_leads_prospek l
JOIN dim_cabang cb ON l.id_cabang = cb.id_cabang
WHERE status_leads = 'Closing'
	AND tgl_closing IS NOT NULL
	AND DATEDIFF(DAY,
		TRY_CAST(tgl_masuk AS DATE),
		TRY_CAST(tgl_closing AS DATE)) BETWEEN 0 AND 90
GROUP BY cb.nama_cabang
ORDER BY avg_hari_closing;

-- Approval rate pengajuan kredit per cabang
SELECT
	cb.nama_cabang,
	COUNT(*) AS total_peengajuan,
	SUM(CASE WHEN status_kredit = 'Approved'
		 	 THEN 1 ELSE 0 END) AS total_approved,
	SUM(CASE WHEN status_kredit = 'Rejected'
			 THEN 1 ELSE 0 END) AS total_rejected,
	CAST(SUM(CASE WHEN status_kredit = 'Approved'
			 THEN 1 ELSE 0 END) * 100.0
	/ NULLIF(COUNT(*),0) AS DECIMAL(5,1)) AS approval_rate_pct
FROM tbl_kredit_pengajuan k
JOIN dim_cabang cb ON k.id_cabang = cb.id_cabang
WHERE flag_penghasilan_anomali = 0
GROUP BY cb.nama_cabang
ORDER BY approval_rate_pct DESC;
-- ...............................................................................................
-- Diagnosis lengkap dalam satu eksekusi
SELECT 'Total baris tabel'         AS cek, 
       COUNT(*) AS n 
FROM tbl_kredit_pengajuan

UNION ALL

SELECT 'Lolos filter flag = 0', 
       COUNT(*) 
FROM tbl_kredit_pengajuan 
WHERE flag_penghasilan_anomali = 0

UNION ALL

SELECT 'Lolos JOIN ke dim_cabang', 
       COUNT(*) 
FROM tbl_kredit_pengajuan k
JOIN dim_cabang cb ON k.id_cabang = cb.id_cabang

UNION ALL

SELECT 'Lolos filter + JOIN', 
       COUNT(*) 
FROM tbl_kredit_pengajuan k
JOIN dim_cabang cb ON k.id_cabang = cb.id_cabang
WHERE flag_penghasilan_anomali = 0;

SELECT 
    flag_penghasilan_anomali, 
    COUNT(*) AS jumlah
FROM tbl_kredit_pengajuan
GROUP BY flag_penghasilan_anomali;
-- .............
SELECT
    cb.nama_cabang,
    COUNT(*)                                        AS total_pengajuan,
    SUM(CASE WHEN status_kredit = 'Approved'
             THEN 1 ELSE 0 END)                     AS total_approved,
    SUM(CASE WHEN status_kredit = 'Rejected'
             THEN 1 ELSE 0 END)                     AS total_rejected,
    CAST(SUM(CASE WHEN status_kredit = 'Approved'
             THEN 1 ELSE 0 END) * 100.0
    / NULLIF(COUNT(*), 0) AS DECIMAL(5,1))          AS approval_rate_pct
FROM tbl_kredit_pengajuan k
JOIN dim_cabang cb ON k.id_cabang = cb.id_cabang
WHERE ISNULL(flag_penghasilan_anomali, 0) = 0   -- fix: NULL diperlakukan sebagai 0
GROUP BY cb.nama_cabang
ORDER BY approval_rate_pct DESC;
-- ..................................................................................................

-- Cabang dengan NPL rate tertinggi
SELECT *
FROM tbl_cabang_master;
GO

WITH cte_cicilan AS (
	SELECT
		id_cabang,
		COUNT(*) AS total_cicilan,
		SUM(CAST(flag_npl AS INT)) AS total_npl
		FROM  fact_kredit
		GROUP BY id_cabang
)
SELECT
	cb.nama_cabang,
	c.total_cicilan,
	c.total_npl,
	CAST(c.total_npl * 100.0
	/ NULLIF(c.total_cicilan,0) AS DECIMAL(5,2)) AS npl_rate_pct
FROM cte_cicilan c
JOIN dim_cabang cb ON c.id_cabang = cb.id_cabang
ORDER BY npl_rate_pct DESC;

-- Total outstanding cicilan per bulan
SELECT
	MONTH(tanggal_jatuh_tempo) AS bulan,
	DATENAME(MONTH, tanggal_jatuh_tempo) AS nama_bulan,
	COUNT(*) AS total_cicilan,
	SUM(CASE WHEN status_bayar != 'Lunas'
		 	 THEN jumlah_cicilan ELSE 0 END) AS outstanding_amount,
	SUM(CASE WHEN status_bayar != 'Lunas'
			 THEN 1 ELSE 0 END) AS jumlah_outstanding
FROM fact_kredit
GROUP BY MONTH(tanggal_jatuh_tempo),
		 DATENAME(MONTH, tanggal_jatuh_tempo)
ORDER BY bulan;
-- ............................................................................
-- Cek isi tabel dan distribusi flag
SELECT 'fact_service - total'          AS cek, COUNT(*) AS n FROM fact_service
UNION ALL
SELECT 'fact_service - flag_jam = 0',          COUNT(*) FROM fact_service WHERE flag_jam_anomali = 0
UNION ALL
SELECT 'fact_service - flag_jam NULL',          COUNT(*) FROM fact_service WHERE flag_jam_anomali IS NULL
UNION ALL
SELECT 'fact_absensi - total',                  COUNT(*) FROM fact_absensi
UNION ALL
SELECT 'fact_absensi - flag_hadir = 0',         COUNT(*) FROM fact_absensi WHERE flag_hadir_tanpa_jam = 0
UNION ALL
SELECT 'fact_absensi - flag_hadir NULL',        COUNT(*) FROM fact_absensi WHERE flag_hadir_tanpa_jam IS NULL
UNION ALL
SELECT 'fact_absensi - is_hadir = 1',           COUNT(*) FROM fact_absensi WHERE is_hadir = 1
UNION ALL
SELECT 'fact_absensi - is_alpha not null',      COUNT(*) FROM fact_absensi WHERE is_alpha IS NOT NULL;
-- ...............................................................................................................
-- Rata-rata durasi pengerjaan service per cabang
SELECT
	 cb.nama_cabang,
	 COUNT(*) AS total_kunjungan,
	 AVG(durasi_menit) AS avg_durasi_menit,
	 MIN(durasi_menit) AS min_durasi,
	 MAX(durasi_menit) AS max_durasi
FROM fact_service s
JOIN dim_cabang cb ON s.id_cabang = cb.id_cabang
WHERE flag_jam_anomali = 0
	AND durasi_menit > 0
GROUP BY cb.nama_cabang
ORDER BY avg_durasi_menit;

SELECT
    cb.nama_cabang,
    COUNT(*)            AS total_kunjungan,
    AVG(durasi_menit)   AS avg_durasi_menit,
    MIN(durasi_menit)   AS min_durasi,
    MAX(durasi_menit)   AS max_durasi
FROM fact_service s
JOIN dim_cabang cb ON s.id_cabang = cb.id_cabang
WHERE ISNULL(s.flag_jam_anomali, 0) = 0
    AND s.durasi_menit > 0
GROUP BY cb.nama_cabang
ORDER BY avg_durasi_menit;
-- .....................................................................................
SELECT 
    'durasi > 0'     AS cek, COUNT(*) AS n 
FROM fact_service 
WHERE ISNULL(flag_jam_anomali, 0) = 0
    AND durasi_menit > 0

UNION ALL

SELECT 
    'durasi = 0',             COUNT(*) 
FROM fact_service 
WHERE ISNULL(flag_jam_anomali, 0) = 0
    AND durasi_menit = 0

UNION ALL

SELECT 
    'durasi NULL',            COUNT(*) 
FROM fact_service 
WHERE ISNULL(flag_jam_anomali, 0) = 0
    AND durasi_menit IS NULL

UNION ALL

SELECT 
    'durasi < 0',             COUNT(*) 
FROM fact_service 
WHERE ISNULL(flag_jam_anomali, 0) = 0
    AND durasi_menit < 0;

UPDATE fact_service
SET durasi_menit = ABS(CHECKSUM(NEWID())) % 151 + 30
-- menghasilkan angka random antara 30 sampai 180 menit
WHERE durasi_menit IS NULL;

UPDATE fact_service
SET durasi_menit = ABS(CHECKSUM(NEWID())) % 151 + 30
WHERE durasi_menit IS NULL;
GO
SELECT 
    COUNT(*)            AS total_baris,
    COUNT(durasi_menit) AS durasi_terisi,
    MIN(durasi_menit)   AS min_menit,
    MAX(durasi_menit)   AS max_menit,
    AVG(durasi_menit)   AS avg_menit
FROM fact_service;
-- ....................................................................................................
-- Mekanik dengan produktivitas tinggi
SELECT
	k.nama_karyawan AS nama_mekanik,
	cb.nama_cabang,
	COUNT(s.id_service) AS jumlah_kendaraan,
	AVG(CAST(s.csi_score AS FLOAT)) AS avg_csi,
	AVG(s.durasi_menit) AS avg_durasi_menit,
	SUM(s.biaya_jasa) AS total_pendapatan_jasa
FROM fact_service s
JOIN dim_karyawan k ON s.id_mekanik = k.id_karyawan
JOIN dim_cabang cb ON s.id_cabang = cb.id_cabang
WHERE ISNULL (s.flag_jam_anomali, 0) = 0
	AND s.csi_score > 0
	AND s.durasi_menit > 0
	AND s.id_mekanik != 'EMP-XXXX'
GROUP BY k.nama_karyawan, cb.nama_cabang
ORDER BY jumlah_kendaraan DESC;

-- Persentase repeat customer yang kembali servis
WITH cte_visit AS (
	SELECT id_pelanggan, COUNT(*) AS jumlah_kunjungan
	FROM fact_service
	WHERE id_pelanggan NOT LIKE 'PEL-WALK%'
	GROUP BY id_pelanggan
)
SELECT
	COUNT(*) AS total_pelanggan,
	SUM(CASE WHEN jumlah_kunjungan > 1
		 THEN 1 ELSE 0 END) AS repeat_customer,
	CAST(SUM(CASE WHEN jumlah_kunjungan > 1
		 THEN 1 ELSE 0 END) * 100.0
	/ NULLIF(COUNT(*), 0) AS DECIMAL(5,1)) AS repeat_rate_pct
FROM cte_visit;

-- DIvisi dengan Alpha rate tertinggi
SELECT
    divisi,
    COUNT(*)          AS total_hari_kerja,
    SUM(is_alpha)     AS total_alpha,
    CAST(SUM(is_alpha) * 100.0
    / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS alpha_rate_pct
FROM fact_absensi
WHERE ISNULL(flag_hadir_tanpa_jam, 0) = 0    -- fix: NULL dianggap valid
GROUP BY divisi
ORDER BY alpha_rate_pct DESC;

-- Cabang dengan keterlambatan masuk kerja tinggi
WITH cte_absensi AS (
    SELECT
        id_cabang,
        COUNT(*)                              AS total_hadir,
        SUM(CAST(ISNULL(flag_terlambat, 0) AS INT)) AS total_terlambat  -- fix NULL flag_terlambat
    FROM fact_absensi
    WHERE is_hadir = 1
        AND ISNULL(flag_hadir_tanpa_jam, 0) = 0    -- fix: sama seperti Query 11
    GROUP BY id_cabang
)
SELECT
    cb.nama_cabang,
    a.total_hadir,
    a.total_terlambat,
    CAST(a.total_terlambat * 100.0
    / NULLIF(a.total_hadir, 0) AS DECIMAL(5,1)) AS terlambat_rate_pct
FROM cte_absensi a
JOIN dim_cabang cb ON a.id_cabang = cb.id_cabang
ORDER BY terlambat_rate_pct DESC;

-- Total cost lembur per divisi per bulan
SELECT 
	divisi,
	MONTH(tanggal) AS bulan,
	DATENAME(MONTH, tanggal) AS nama_bulan,
	SUM(overtime_jam) AS total_jam_lembur,
	CAST(SUM(cost_lembur) AS BIGINT) AS total_cost_lembur
FROM fact_absensi
WHERE overtime_jam > 0
GROUP BY divisi, MONTH(tanggal), DATENAME(MONTH, tanggal)
ORDER BY divisi, bulan;

-- ...........................
SELECT 
    DATEDIFF(DAY,
        TRY_CAST(tgl_masuk AS DATE),
        TRY_CAST(tgl_closing AS DATE)) AS hari_closing,
    COUNT(*) AS jumlah_closing
FROM tbl_leads_prospek
WHERE status_leads = 'Closing'
    AND tgl_closing IS NOT NULL
GROUP BY DATEDIFF(DAY,
    TRY_CAST(tgl_masuk AS DATE),
    TRY_CAST(tgl_closing AS DATE))
ORDER BY hari_closing;

-- .......
-- Lihat persentil distribusi durasi closing
SELECT TOP 1
    MIN(hari) OVER ()                                   AS min_hari,
    MAX(hari) OVER ()                                   AS max_hari,
    AVG(CAST(hari AS FLOAT)) OVER ()                    AS avg_hari,
    PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY hari) OVER ()                         AS median,
    PERCENTILE_CONT(0.90) WITHIN GROUP
        (ORDER BY hari) OVER ()                         AS persentil_90,
    PERCENTILE_CONT(0.95) WITHIN GROUP
        (ORDER BY hari) OVER ()                         AS persentil_95
FROM (
    SELECT DATEDIFF(DAY,
        TRY_CAST(tgl_masuk AS DATE),
        TRY_CAST(tgl_closing AS DATE)) AS hari
    FROM tbl_leads_prospek
    WHERE status_leads = 'Closing'
        AND tgl_closing IS NOT NULL
) sub;

-- ..................
ALTER TABLE dim_cabang ADD latitude FLOAT, longitude FLOAT;
GO
UPDATE dim_cabang SET
    latitude = -7.2575,  longitude = 112.7521 WHERE nama_cabang = 'Surabaya Pusat';
UPDATE dim_cabang SET
    latitude = -7.2459,  longitude = 112.7378 WHERE nama_cabang = 'Surabaya Barat';
UPDATE dim_cabang SET
    latitude = -7.9797,  longitude = 112.6304 WHERE nama_cabang = 'Malang Kota';
UPDATE dim_cabang SET
    latitude = -8.1845,  longitude = 113.1686 WHERE nama_cabang = 'Jember';
UPDATE dim_cabang SET
    latitude = -7.8480,  longitude = 112.5261 WHERE nama_cabang = 'Malang Selatan';
UPDATE dim_cabang SET
    latitude = -7.1600,  longitude = 112.7068 WHERE nama_cabang = 'Gresik';
UPDATE dim_cabang SET
    latitude = -7.4478,  longitude = 112.7183 WHERE nama_cabang = 'Sidoarjo';
UPDATE dim_cabang SET
    latitude = -7.8167,  longitude = 112.0124 WHERE nama_cabang = 'Kediri';
UPDATE dim_cabang SET
    latitude = -7.0051,  longitude = 110.4381 WHERE nama_cabang = 'Semarang Pusat';
UPDATE dim_cabang SET
    latitude = -6.9667,  longitude = 110.3833 WHERE nama_cabang = 'Semarang Barat';
UPDATE dim_cabang SET
    latitude = -7.5560,  longitude = 110.8317 WHERE nama_cabang = 'Solo';
UPDATE dim_cabang SET
    latitude = -7.7971,  longitude = 110.3688 WHERE nama_cabang = 'Yogyakarta';
