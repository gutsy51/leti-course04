import random
import math
import matplotlib.pyplot as plt
import numpy as np

random.seed(0)

N = 10000     # объём выборки
X = []        # контейнер для данных


def stats_report(name, X, M_exp, D_exp):
    """Печать статистики и ошибок."""
    N = len(X)
    M = sum(X) / N
    D = sum(x*x for x in X) / N - M**2

    dM = abs((M - M_exp) / M_exp) * 100 if M_exp != 0 else 0
    dD = abs((D - D_exp) / D_exp) * 100 if D_exp != 0 else 0

    print(f"\n=== {name} ===")
    print(f"Эмпирические:   M = {M:.4f},  D = {D:.4f}")
    print(f"Теоретические:  M = {M_exp:.4f},  D = {D_exp:.4f}")
    print(f"Относит. ошибки: δM = {dM:.2f} %,  δD = {dD:.2f} %")

    # Гистограмма
    plt.figure(figsize=(7,4))
    plt.hist(X, bins=25, weights=np.ones(len(X))/len(X),
             edgecolor='black', color='skyblue')
    plt.title(name)
    plt.xlabel("x")
    plt.ylabel("p")
    plt.tight_layout()
    plt.show()


# 1. Экспоненциальное распределение
lambda_ = 3
X = [ -1/lambda_ * math.log(random.random()) for _ in range(N) ]

M_exp = 1/lambda_
D_exp = 1/(lambda_**2)

stats_report("Экспоненциальное", X, M_exp, D_exp)


# 2. Равномерное распределение [A, B]
A, B = 1, 5
X = [ A + (B-A)*random.random() for _ in range(N) ]

M_exp = A + (B-A)/2
D_exp = (B-A)**2 / 12

stats_report("Равномерное", X, M_exp, D_exp)


# 3. Эрланга порядка k
k = 4
lambda_ = 1

X = []
for _ in range(N):
    prod = 1
    for j in range(k):
        prod *= random.random()
    X.append(-1/lambda_ * math.log(prod))

M_exp = k/lambda_
D_exp = k/(lambda_**2)

stats_report("Эрланга", X, M_exp, D_exp)


# 4. Нормальное распределение (Box–Muller)
X = []
for i in range(N // 2):
    u1 = random.random()
    u2 = random.random()
    r = math.sqrt(-2 * math.log(u1))
    X.append(r * math.cos(2 * math.pi * u2))
    X.append(r * math.sin(2 * math.pi * u2))

M_exp = 0
D_exp = 1

stats_report("Нормальное (стандартное)", X, M_exp, D_exp)


# 5. Распределение Пуассона (алгоритм Кнута)
lambda_ = 4
X = []

for _ in range(N):
    L = math.exp(-lambda_)
    k = 0
    p = 1.0

    while p > L:
        k += 1
        p *= random.random()

    X.append(k - 1)

M_exp = lambda_
D_exp = lambda_

stats_report("Пуассона", X, M_exp, D_exp)
