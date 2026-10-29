import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import seaborn as sns
from sqlalchemy import create_engine
from scipy import stats

from sqlalchemy import create_engine
import urllib

params = urllib.parse.quote_plus(
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=ICH-BIN-18447;"        
    "DATABASE=Nusantara_Sakti_Group;"   
    "Trusted_Connection=yes;"     
)
engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")

df_jual = pd.read_sql('SELECT * FROM fact_penjualan', engine)
df_kredit = pd.read_sql('SELECT * FROM fact_kredit', engine)
df_service = pd.read_sql('SELECT * FROM fact_service', engine)
df_absensi = pd.read_sql('SELECT * FROM fact_absensi', engine)
df_leads = pd.read_sql('SELECT * FROM tbl_leads_prospek', engine)
df_cabang = pd.read_sql('SELECT * FROM dim_cabang', engine)
df_karyawan = pd.read_sql('SELECT * FROM dim_karyawan', engine)

df_jual['tgl_transaksi'] = pd.to_datetime(df_jual['tanggal'])
df_kredit ['tanggal_jatuh_tempo'] = pd.to_datetime(df_kredit['tanggal_jatuh_tempo'])
df_service['tanggal_service'] = pd.to_datetime(df_service['tanggal'])
df_absensi['tanggal'] = pd.to_datetime(df_absensi['tanggal'])

print('Data loaded successfully!')
for name, df in [('Penjualan', df_jual), ('Kredit', df_kredit), ('Service', df_service), ('Absensi', df_absensi)]:
    print(f' {name}: {df.shape[0]} rows, {df.shape[1]} cols')
          
print('\nKolom df_kredit:')
print(df_kredit.columns.tolist())

leads_per_cab = df_leads.groupby('id_cabang').agg(
    total_leads=('id_leads', 'count'),
    total_closing=('status_leads', lambda x: (x == 'Closing').sum()),
).reset_index()

jual_per_cab = df_jual.groupby('id_cabang').agg(
    unit_terjual = ('id_penjualan', 'count')
).reset_index()

corr_df = leads_per_cab.merge(jual_per_cab, on='id_cabang')
corr_df = corr_df.merge(df_cabang[['id_cabang', 'nama_cabang']], on='id_cabang')

r, p = stats.pearsonr(corr_df['total_leads'], corr_df['unit_terjual'])
print(f'Person r: {r:.3f}, p-value: {p:.4f}')

fig, ax = plt.subplots(figsize=(10,6))
ax.scatter(corr_df['total_leads'], corr_df['unit_terjual'],
           s=120, color='steelblue', zorder=3)
for _, row in corr_df.iterrows():
    ax.annotate(row['nama_cabang'], (row['total_leads'], row['unit_terjual']),
                textcoords="offset points", xytext=(5,4), ha='center', fontsize=8)

m,b = np.polyfit(corr_df['total_leads'], corr_df['unit_terjual'], 1)
x = np.linspace(corr_df['total_leads'].min(), corr_df['total_leads'].max(), 100)
ax.plot(x, m*x + b, 'r--', linewidth=1.5, label='Garis Tren')
ax.set_title(f'Korelasi Leads vs Unit Terjual per Cabang\n(Person r={r:.3f})', fontsize=13, fontweight='bold')
ax.set_xlabel('Total Leads Masuk', fontsize=11)
ax.set_ylabel('Total Motor Terjual', fontsize=11)
ax.legend(); ax.grid(True, alpha=0.4, linestyle='--')
plt.tight_layout()
plt.savefig('korelasi_leads_penjualan.png', dpi=150)
plt.show()

df_kredit['flag_npl'] = df_kredit['flag_npl'].fillna(0).astype(int)
df_npl = df_kredit[df_kredit['flag_npl']== 1].copy()
df_ok  = df_kredit[df_kredit['flag_npl']== 0].copy()

print(f'Total NPL : {len(df_npl)} cicilan')
print(f'Total Lunas : {len(df_ok)} cicilan')
total = len(df_npl) + len(df_ok)
if total > 0:
    print(f'NPL Rate : {len(df_npl) / total * 100:.1f}%')
else:
    print('NPL Rate : Data tidak tersedia')

fig, axes = plt.subplots(1, 3, figsize=(16, 5))

pekerjaan = df_npl ['pekerjaan'].value_counts()
axes[0].barh(pekerjaan.index, pekerjaan.values, color='tomato')
axes[0].set_title('pekerjaan Debitur NPL', fontweight='bold')
axes[0].set_xlabel('Jumlah NPL')

if len(df_npl) == 0:
    axes[0].text(0.5, 0.5, 'Data NPL tidak tersedia',
                 ha='center', va='center',
                 transform=axes[0].transAxes,
                 fontsize=11, color='gray')
    axes[2].text(0.5, 0.5, 'Data NPL tidak tersedia',
                 ha='center', va='center',
                 transform=axes[2].transAxes,
                 fontsize=11, color='gray')

axes[1].hist(df_npl['penghasilan_bulanan']/1e6, bins=15, color='tomato', alpha=0.7, label='NPL')
axes[1].hist(df_ok['penghasilan_bulanan']/1e6, bins=15, color='steelblue', alpha=0.5, label='Lunas')
axes[1].set_xlabel('Penghasilan (Juta Rp)')
axes[1].legend()

tenor_npl = df_npl['tenor_bulan'].value_counts().sort_index()
tenor_ok = df_ok['tenor_bulan'].value_counts().sort_index()
x = np.arange(len(tenor_npl))
axes[2].bar(x-0.2, tenor_npl.values, 0.4, color='tomato', label='NPL')
axes[2].bar(x+0.2, tenor_ok.reindex(tenor_npl.index, fill_value=0).values, 0.4, color='steelblue', label='Lunas')
axes[2].set_xticks(x)
axes[2].set_xticklabels([f'{t} bln' for t in tenor_npl.index])
axes[2].set_title('Distribusi Tenor', fontweight='bold')
axes[2].legend()

plt.suptitle('Profil Debitur NPL vs Lunas', fontsize=14, fontweight='bold')
plt.tight_layout()
plt.savefig('Q8_profil_ebitur_npl.png', dpi=150)
plt.show()

# Lag Analysis: Penjualan vs Volume Servis Bulan Berikutnya
jual_bln = df_jual.groupby(df_jual['tgl_transaksi'].dt.month).agg(
    unit_terjual=('id_penjualan', 'count')
) .reset_index()
jual_bln.columns = ['bulan', 'unit_terjual']

serv_bln = df_service.groupby(df_service['tanggal_service'].dt.month).agg(
    volume_service=('id_service', 'count')
).reset_index()
serv_bln.columns = ['bulan', 'volume_service']

jual_lag = jual_bln.copy()
jual_lag['bulan_lag'] = jual_lag['bulan'] + 1
lag_df = jual_lag.merge(serv_bln,
                        left_on='bulan_lag', right_on='bulan',
                        suffixes=('_jual', '_serv'))
print('Lag Analysis table:')
print(lag_df[['bulan_jual','unit_terjual','bulan_lag','volume_service']])

if len(lag_df) >= 2:
    r, p= stats.pearsonr(lag_df['unit_terjual'], lag_df['volume_service'])
    print(f'Pearson r = {r:3f}, p-value = {p:.4f}')

fig, ax1 = plt.subplots(figsize=(10,5))
bulan_label = ['Januari', 'Februari', 'Maret']
ax2 = ax1.twinx()
ax1.bar([b-0.2 for b in jual_bln ['bulan']], jual_bln['unit_terjual'], 0.4, color='steelblue', label='Unit Terjual')
ax2.plot(serv_bln['bulan'], serv_bln['volume_service'], 'o-', color='tomato', linewidth=2, label='Volume Service')
ax1.set_xlabel('Bulan')
ax1.set_ylabel('Unit Terjual', color='steelblue')
ax2.set_ylabel('Volume Service', color='tomato')
ax1.set_xticks([1,2,3])
ax1.set_title('Lag Analysis: Penjualan Motor vs Volume Service', fontsize=13, fontweight='bold')

lines1, labels1 = ax1.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax1.legend(lines1+lines2, labels1+labels2, loc='upper right')
plt.tight_layout()
plt.savefig('Q13_lag_penjualan_service.png', dpi=150)
plt.show()

# Korelasi Absensi Sales vs Pencapaian Target
absensi_sales = df_absensi[df_absensi['divisi'] == 'Sales']
alpha_cab = absensi_sales.groupby('id_cabang').agg(
    total_absensi=('id_absensi', 'count'),
    total_alpha=('is_alpha', 'sum')
).reset_index()
alpha_cab['alpha_rate'] = (
alpha_cab['total_alpha'] / alpha_cab['total_absensi'] * 100
)

achive_df = pd.read_sql('''
    WITH a AS (SELECT id_cabang, COUNT(*) AS unit_aktual
    FROM fact_penjualan GROUP BY id_cabang),
         t AS (SELECT id_cabang, SUM(target_unit) AS unit_target
               FROM tbl_sales_target GROUP BY id_cabang)
    SELECT a.id_cabang,
        CAST(a.unit_aktual*100.0/NULLIF(t.unit_target,0) AS FLOAT)
        AS achivement_pct
    FROM a JOIN t ON a.id_cabang=t.id_cabang
''', engine)

corr2 = alpha_cab.merge(achive_df, on='id_cabang')
corr2 = corr2.merge(df_cabang[['id_cabang', 'nama_cabang']], on='id_cabang')

r, p = stats.pearsonr(corr2['alpha_rate'], corr2['achivement_pct'])
print(f'Pearson r: {r:.3f}, p-value: {p:.4f}')

fig, ax = plt.subplots(figsize=(10,6))
ax.scatter(corr2['alpha_rate'], corr2['achivement_pct'],
           s=120, color='steelblue', zorder=3)
for _, row in corr2.iterrows():
    ax.annotate(row['nama_cabang'], (row['alpha_rate'], row['achivement_pct']),
               xytext=(5,4), textcoords="offset points", ha='center', fontsize=8)
m, b = np.polyfit(corr2['alpha_rate'], corr2['achivement_pct'], 1)
x = np.linspace(corr2['alpha_rate'].min(), corr2['alpha_rate'].max(), 100)
ax.plot(x, m*x + b, 'r--', linewidth=1.5, label='Garis Tren')
ax.set_title(
    f'Korelasi Alpha Rate Sales vs Achievement target\n(Person r={r:.3f})', 
    fontsize=13, fontweight='bold')
ax.set_xlabel('Alpha Rate Sales (%)', fontsize=11)
ax.set_ylabel('Achievement Target (%)', fontsize=11)
ax.legend(); ax.grid(True, alpha=0.4, linestyle='--')
plt.tight_layout()
plt.savefig('Q14_korelasi_alpha_achivement.png', dpi=150)
plt.show()