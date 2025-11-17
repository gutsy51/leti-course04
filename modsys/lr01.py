import numpy as np
import matplotlib.pyplot as plt

# Параметры
r = 16
M = 101
T = 2**(r-2)
n = T
m = 4
s_values = [2, 5, 10]

# Генерация основной последовательности
A = np.zeros(n, dtype=int)
Z = np.zeros(n, dtype=float)
A[0] = 1

for i in range(1, n):
    A[i] = (A[i-1] * M) % 2**r

# Построение подпоследовательностей
seqs_num = n // m
Akm = np.zeros((m, seqs_num), dtype=int)
for j in range(m):
    Akm[j, 0] = A[j]

for i in range(1, seqs_num):
    for j in range(m):
        Akm[j, i] = (Akm[j, i-1] * pow(M, m, 2**r)) % 2**r

# Получение базовой случайной величины Z
k = 0
for i in range(seqs_num):
    for j in range(m):
        Z[k] = Akm[j, i] / 2**r
        k += 1

# Математическое ожидание и дисперсия
M_hat = np.mean(Z)
D_hat = np.var(Z)
print(f"Эмпирическое M = {M_hat:.4f}, теоретическое M = 0.5")
print(f"Эмпирическая D = {D_hat:.4f}, теоретическая D = {1/12:.4f}")

# Гистограмма
plt.figure(figsize=(10,8))
plt.scatter(range(n), Z, s=3, color='blue')
plt.xlabel("Индекс")
plt.ylabel("Z")
plt.show()

# Распределение
K = 10
counts, bins = np.histogram(Z, bins=K, range=(0,1))
p = counts / n

plt.figure(figsize=(8,4))
plt.bar(bins[:-1], p, width=1/K, edgecolor='black', color='orange')
plt.xlabel("Интервал")
plt.ylabel("Относительная частота")
plt.show()

# Коэффициент корреляции
plt.figure(figsize=(10,5))
for s in s_values:
    Rs = []
    step = 100
    for l in range(step, n+1, step):
        z_slice = Z[:l]
        Mz = np.mean(z_slice)
        numerator = np.sum((z_slice[:l-s]-Mz)*(z_slice[s:l]-Mz))
        denominator = np.sum((z_slice[:l-s]-Mz)**2)
        R = numerator / denominator
        Rs.append(R)
    plt.plot(range(step, n+1, step), Rs, label=f's={s}')

plt.xlabel("Объем выборки n")
plt.ylabel("Коэффициент корреляции R")
plt.axhline(0, color='black', linewidth=0.8)
plt.legend()
plt.grid(True)
plt.show()
