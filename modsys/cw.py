"""
ИМИТАЦИОННАЯ МОДЕЛЬ РАСПРЕДЕЛЕННОГО БАНКА ДАННЫХ
Вариант 18. Курсовая работа по моделированию систем массового обслуживания
"""

import random
import heapq
from collections import deque, defaultdict
import matplotlib.pyplot as plt
import numpy as np
from typing import List, Tuple, Dict, Optional
import time

# ============================================================================
# КОНСТАНТЫ И ПАРАМЕТРЫ МОДЕЛИ
# ============================================================================

class Config:
    """Конфигурационные параметры системы"""
    # Параметры временных интервалов
    GEN_MIN = 7.0      # Минимальное время между заявками (сек)
    GEN_MAX = 13.0     # Максимальное время между заявками (сек)
    PRIM_TIME = 2.0    # Время первичной обработки (сек)
    ANS_MIN = 16.0     # Минимальное время ответа (сек)
    ANS_MAX = 20.0     # Максимальное время ответа (сек)
    TRANS_TIME = 3.0   # Время передачи по каналу (сек)

    # Вероятности
    P_LOCAL = 0.5      # Вероятность локального обслуживания

    # Ограничения моделирования
    TOTAL_REQUESTS = 400  # Общее количество заявок для обработки

    # Параметры для улучшенной системы
    IMPROVED_SYSTEM = False  # Флаг для включения улучшенной системы (2 прибора ЭВМ1-ок)

    # Цвета для визуализации
    COLORS = {
        'device': '#f8cecc',
        'queue': '#dae8fc',
        'channel': '#ffe6cc',
        'evm2': '#daebe8',
        'source': '#fff2cc',
        'exit': '#d5e8d4'
    }


# ============================================================================
# ОСНОВНЫЕ КЛАССЫ МОДЕЛИ
# ============================================================================

class Request:
    """Класс, представляющий заявку (запрос) в системе"""
    _id_counter = 1

    def __init__(self, creation_time: float):
        self.id = Request._id_counter
        Request._id_counter += 1
        self.creation_time = creation_time  # Время создания заявки
        self.start_time = None              # Время начала обслуживания
        self.finish_time = None             # Время окончания обслуживания
        self.path = None                    # Маршрут: 'local' или 'remote'
        self.queue_times = {}               # Время ожидания в очередях

    def total_time(self) -> float:
        """Общее время пребывания в системе"""
        if self.finish_time:
            return self.finish_time - self.creation_time
        return 0.0

    def __repr__(self):
        return f"Request(id={self.id}, path={self.path}, time={self.total_time():.2f})"


class Event:
    """Класс события для календаря событий"""
    def __init__(self, time: float, event_type: str, data=None):
        self.time = time
        self.event_type = event_type
        self.data = data

    def __lt__(self, other):
        return self.time < other.time

    def __repr__(self):
        return f"Event({self.event_type}, t={self.time:.2f})"


class Device:
    """Класс, представляющий прибор обслуживания"""
    def __init__(self, name: str, service_time_func, max_parallel=1):
        self.name = name
        self.service_time_func = service_time_func  # Функция генерации времени обслуживания
        self.max_parallel = max_parallel            # Максимальное количество параллельных обрабок
        self.parallel_count = 0                     # Текущее количество обрабатываемых заявок
        self.queue = deque()                        # Очередь заявок
        self.history = []                           # История состояний прибора
        self.total_processed = 0                    # Общее количество обработанных заявок
        self.busy_time = 0.0                        # Общее время занятости

    def is_available(self) -> bool:
        """Проверка, доступен ли прибор для обслуживания"""
        return self.parallel_count < self.max_parallel

    def can_accept(self) -> bool:
        """Может ли прибор принять новую заявку"""
        return True  # По умолчанию не ограничено

    def start_service(self, request: Request, current_time: float) -> float:
        """Начать обслуживание заявки, вернуть время окончания"""
        if not self.is_available():
            raise Exception(f"Device {self.name} is not available")

        self.parallel_count += 1
        request.start_time = current_time
        service_time = self.service_time_func()
        end_time = current_time + service_time

        # Запись в историю
        self.history.append((current_time, 'start', request.id, service_time))

        return end_time

    def finish_service(self, request: Request, current_time: float):
        """Завершить обслуживание заявки"""
        self.parallel_count -= 1
        self.total_processed += 1
        request.finish_time = current_time

        # Обновление времени занятости
        if request.start_time:
            self.busy_time += (current_time - request.start_time)

        # Запись в историю
        self.history.append((current_time, 'finish', request.id))

    def add_to_queue(self, request: Request, current_time: float):
        """Добавить заявку в очередь"""
        self.queue.append((current_time, request))
        return len(self.queue)

    def get_from_queue(self, current_time: float) -> Tuple[Request, float]:
        """Извлечь заявку из очереди"""
        if not self.queue:
            return None, 0.0

        queue_time, request = self.queue.popleft()
        wait_time = current_time - queue_time
        request.queue_times[self.name] = wait_time
        return request, wait_time

    def queue_length(self) -> int:
        """Текущая длина очереди"""
        return len(self.queue)

    def utilization(self, total_time: float) -> float:
        """Коэффициент загрузки прибора"""
        if total_time > 0:
            return self.busy_time / total_time
        return 0.0


# ============================================================================
# КЛАСС МОДЕЛИ
# ============================================================================

class DistributedDBModel:
    """Основной класс имитационной модели распределенного банка данных"""

    def __init__(self, improved_system=False, max_queue_size=None):
        # Параметры системы
        self.improved = improved_system
        self.max_queue_size = max_queue_size

        # Временные переменные
        self.current_time = 0.0
        self.event_list = []  # Календарь событий (куча)

        # Счетчики
        self.request_counter = 0
        self.processed_requests = 0
        self.lost_requests = 0

        # Списки заявок
        self.active_requests = []
        self.finished_requests = []

        # Инициализация приборов
        self._init_devices()

        # Статистика
        self.stats = {
            'queue_lengths': defaultdict(list),  # История длин очередей
            'queue_max': defaultdict(int),        # Максимальные длины очередей
            'queue_avg': defaultdict(float),      # Средние длины очередей
            'queue_samples': defaultdict(int),    # Количество замеров для очередей
            'wait_times': defaultdict(list),      # Время ожидания в очередях
            'service_times': [],                  # Время обслуживания
            'system_times': [],                   # Время в системе
            'events_processed': 0,                # Количество обработанных событий
            'last_stat_time': 0.0,                # Время последнего сбора статистики
        }

    def _init_devices(self):
        """Инициализация всех приборов системы"""

        # Функции генерации времен обслуживания
        def gen_interarrival():
            return random.uniform(Config.GEN_MIN, Config.GEN_MAX)

        def gen_answer_time():
            return random.uniform(Config.ANS_MIN, Config.ANS_MAX)

        # Создание приборов
        self.devices = {
            # Источник заявок (виртуальный прибор)
            'SOURCE': Device('SOURCE', gen_interarrival),

            # ЭВМ1: Первичная обработка
            'EV1_PRIMARY': Device('EV1_PRIMARY', lambda: Config.PRIM_TIME),

            # ЭВМ1: Окончательная обработка
            'EV1_FINAL': Device('EV1_FINAL', gen_answer_time,
                                max_parallel=2 if self.improved else 1),

            # Канал связи
            'CHANNEL': Device('CHANNEL', lambda: Config.TRANS_TIME),

            # ЭВМ2: Первичная обработка
            'EV2_PRIMARY': Device('EV2_PRIMARY', lambda: Config.PRIM_TIME),

            # ЭВМ2: Окончательная обработка
            'EV2_FINAL': Device('EV2_FINAL', gen_answer_time),
        }

        # Специальные очереди (отдельно от приборов)
        self.queues = {
            'Q1': deque(),  # Очередь перед EV1_PRIMARY
            'Q2': deque(),  # Очередь перед EV1_FINAL
            'Q3': deque(),  # Очередь перед EV2_PRIMARY
        }

        # История для очередей
        self.queue_history = {name: [] for name in self.queues.keys()}

    def _schedule_event(self, event: Event):
        """Добавить событие в календарь"""
        heapq.heappush(self.event_list, event)

    def _collect_queue_stats(self):
        """Сбор статистики по очередям"""
        for q_name, q in self.queues.items():
            q_len = len(q)
            self.stats['queue_lengths'][q_name].append((self.current_time, q_len))

            # Обновление максимальной длины
            if q_len > self.stats['queue_max'][q_name]:
                self.stats['queue_max'][q_name] = q_len

            # Обновление средней длины (скользящее среднее)
            prev_avg = self.stats['queue_avg'][q_name]
            prev_samples = self.stats['queue_samples'][q_name]
            new_avg = (prev_avg * prev_samples + q_len) / (prev_samples + 1)
            self.stats['queue_avg'][q_name] = new_avg
            self.stats['queue_samples'][q_name] += 1

    def _arrival_event(self):
        """Обработка события прибытия новой заявки"""
        # Создание новой заявки
        request = Request(self.current_time)
        self.active_requests.append(request)
        self.request_counter += 1

        # Добавление в очередь Q1
        if self.max_queue_size and len(self.queues['Q1']) >= self.max_queue_size:
            self.lost_requests += 1
            print(f"  [WARN] Заявка {request.id} потеряна (очередь Q1 переполнена)")
        else:
            self.queues['Q1'].append((self.current_time, request))
            self._collect_queue_stats()

            # Попытка начать обработку на EV1_PRIMARY
            self._try_start_ev1_primary()

        # Планирование следующего прибытия
        if self.request_counter < Config.TOTAL_REQUESTS:
            interarrival = self.devices['SOURCE'].service_time_func()
            next_arrival = self.current_time + interarrival
            self._schedule_event(Event(next_arrival, 'ARRIVAL'))

    def _try_start_ev1_primary(self):
        """Попытка начать обработку на EV1_PRIMARY"""
        if self.queues['Q1'] and self.devices['EV1_PRIMARY'].is_available():
            # Извлечение заявки из очереди
            arrival_time, request = self.queues['Q1'].popleft()
            wait_time = self.current_time - arrival_time
            request.queue_times['Q1'] = wait_time
            self.stats['wait_times']['Q1'].append(wait_time)
            self._collect_queue_stats()

            # Начало обслуживания
            service_time = Config.PRIM_TIME
            end_time = self.current_time + service_time

            # Запись в историю прибора
            self.devices['EV1_PRIMARY'].history.append(
                (self.current_time, 'start', request.id, service_time)
            )
            self.devices['EV1_PRIMARY'].parallel_count += 1

            # Планирование окончания обработки
            self._schedule_event(Event(end_time, 'EV1_PRIMARY_END', request))

    def _ev1_primary_end_event(self, request: Request):
        """Обработка окончания первичной обработки на ЭВМ1"""
        # Освобождение прибора
        self.devices['EV1_PRIMARY'].parallel_count -= 1
        self.devices['EV1_PRIMARY'].total_processed += 1
        self.devices['EV1_PRIMARY'].busy_time += Config.PRIM_TIME
        self.devices['EV1_PRIMARY'].history.append(
            (self.current_time, 'finish', request.id)
        )

        # Определение маршрута
        if random.random() < Config.P_LOCAL:
            request.path = 'local'
            # Добавление в очередь Q2
            self.queues['Q2'].append((self.current_time, request))
            self._collect_queue_stats()
            self._try_start_ev1_final()
        else:
            request.path = 'remote'
            # Добавление в очередь канала
            if self.devices['CHANNEL'].is_available():
                self._start_channel_transfer(request)
            else:
                self.devices['CHANNEL'].add_to_queue(request, self.current_time)

        # Попытка начать обработку следующей заявки из Q1
        self._try_start_ev1_primary()

    def _try_start_ev1_final(self):
        """Попытка начать окончательную обработку на ЭВМ1"""
        if self.queues['Q2'] and self.devices['EV1_FINAL'].is_available():
            # Извлечение заявки из очереди
            arrival_time, request = self.queues['Q2'].popleft()
            wait_time = self.current_time - arrival_time
            request.queue_times['Q2'] = wait_time
            self.stats['wait_times']['Q2'].append(wait_time)
            self._collect_queue_stats()

            # Начало обслуживания
            service_time = random.uniform(Config.ANS_MIN, Config.ANS_MAX)
            end_time = self.current_time + service_time

            # Запись в историю прибора
            self.devices['EV1_FINAL'].history.append(
                (self.current_time, 'start', request.id, service_time)
            )
            self.devices['EV1_FINAL'].parallel_count += 1

            # Планирование окончания обработки
            self._schedule_event(Event(end_time, 'EV1_FINAL_END', request))

    def _start_channel_transfer(self, request: Request):
        """Начать передачу по каналу"""
        service_time = Config.TRANS_TIME
        end_time = self.current_time + service_time

        self.devices['CHANNEL'].history.append(
            (self.current_time, 'start', request.id, service_time)
        )
        self.devices['CHANNEL'].parallel_count += 1

        self._schedule_event(Event(end_time, 'CHANNEL_END', request))

    def _channel_end_event(self, request: Request):
        """Обработка окончания передачи по каналу"""
        # Освобождение канала
        self.devices['CHANNEL'].parallel_count -= 1
        self.devices['CHANNEL'].total_processed += 1
        self.devices['CHANNEL'].busy_time += Config.TRANS_TIME
        self.devices['CHANNEL'].history.append(
            (self.current_time, 'finish', request.id)
        )

        # Проверка очереди канала
        if self.devices['CHANNEL'].queue:
            next_request, _ = self.devices['CHANNEL'].get_from_queue(self.current_time)
            self._start_channel_transfer(next_request)

        # Добавление заявки в очередь Q3
        self.queues['Q3'].append((self.current_time, request))
        self._collect_queue_stats()
        self._try_start_ev2_primary()

    def _try_start_ev2_primary(self):
        """Попытка начать обработку на ЭВМ2 (первичная)"""
        if self.queues['Q3'] and self.devices['EV2_PRIMARY'].is_available():
            # Извлечение заявки из очереди
            arrival_time, request = self.queues['Q3'].popleft()
            wait_time = self.current_time - arrival_time
            request.queue_times['Q3'] = wait_time
            self.stats['wait_times']['Q3'].append(wait_time)
            self._collect_queue_stats()

            # Начало обслуживания
            service_time = Config.PRIM_TIME
            end_time = self.current_time + service_time

            # Запись в историю прибора
            self.devices['EV2_PRIMARY'].history.append(
                (self.current_time, 'start', request.id, service_time)
            )
            self.devices['EV2_PRIMARY'].parallel_count += 1

            # Планирование окончания обработки
            self._schedule_event(Event(end_time, 'EV2_PRIMARY_END', request))

    def _ev2_primary_end_event(self, request: Request):
        """Обработка окончания первичной обработки на ЭВМ2"""
        # Освобождение прибора
        self.devices['EV2_PRIMARY'].parallel_count -= 1
        self.devices['EV2_PRIMARY'].total_processed += 1
        self.devices['EV2_PRIMARY'].busy_time += Config.PRIM_TIME
        self.devices['EV2_PRIMARY'].history.append(
            (self.current_time, 'finish', request.id)
        )

        # Начало окончательной обработки на ЭВМ2
        if self.devices['EV2_FINAL'].is_available():
            self._start_ev2_final(request)
        else:
            self.devices['EV2_FINAL'].add_to_queue(request, self.current_time)

        # Попытка начать обработку следующей заявки из Q3
        self._try_start_ev2_primary()

    def _start_ev2_final(self, request: Request):
        """Начать окончательную обработку на ЭВМ2"""
        service_time = random.uniform(Config.ANS_MIN, Config.ANS_MAX)
        end_time = self.current_time + service_time

        self.devices['EV2_FINAL'].history.append(
            (self.current_time, 'start', request.id, service_time)
        )
        self.devices['EV2_FINAL'].parallel_count += 1

        self._schedule_event(Event(end_time, 'EV2_FINAL_END', request))

    def _ev1_final_end_event(self, request: Request):
        """Обработка окончания на ЭВМ1 (завершение обслуживания)"""
        # Освобождение прибора
        self.devices['EV1_FINAL'].parallel_count -= 1
        self.devices['EV1_FINAL'].total_processed += 1

        # Расчет времени обслуживания
        start_event = next((h for h in self.devices['EV1_FINAL'].history
                            if h[1] == 'start' and h[2] == request.id), None)
        if start_event:
            service_time = start_event[3]
            self.devices['EV1_FINAL'].busy_time += service_time

        self.devices['EV1_FINAL'].history.append(
            (self.current_time, 'finish', request.id)
        )

        # Завершение обслуживания заявки
        request.finish_time = self.current_time
        self.finished_requests.append(request)
        self.active_requests.remove(request)
        self.processed_requests += 1

        # Сбор статистики по времени
        total_time = request.total_time()
        self.stats['system_times'].append(total_time)

        # Попытка начать обработку следующей заявки из Q2
        self._try_start_ev1_final()

        # Проверка очереди прибора EV1_FINAL
        if self.devices['EV1_FINAL'].queue:
            next_request, _ = self.devices['EV1_FINAL'].get_from_queue(self.current_time)
            self._start_ev2_final(next_request)

    def _ev2_final_end_event(self, request: Request):
        """Обработка окончания на ЭВМ2 (завершение обслуживания)"""
        # Освобождение прибора
        self.devices['EV2_FINAL'].parallel_count -= 1
        self.devices['EV2_FINAL'].total_processed += 1

        # Расчет времени обслуживания
        start_event = next((h for h in self.devices['EV2_FINAL'].history
                            if h[1] == 'start' and h[2] == request.id), None)
        if start_event:
            service_time = start_event[3]
            self.devices['EV2_FINAL'].busy_time += service_time

        self.devices['EV2_FINAL'].history.append(
            (self.current_time, 'finish', request.id)
        )

        # Завершение обслуживания заявки
        request.finish_time = self.current_time
        self.finished_requests.append(request)
        self.active_requests.remove(request)
        self.processed_requests += 1

        # Сбор статистики по времени
        total_time = request.total_time()
        self.stats['system_times'].append(total_time)

        # Проверка очереди прибора EV2_FINAL
        if self.devices['EV2_FINAL'].queue:
            next_request, _ = self.devices['EV2_FINAL'].get_from_queue(self.current_time)
            self._start_ev2_final(next_request)

    def run(self, verbose=False):
        """Основной цикл моделирования"""
        print(f"{'='*60}")
        print(f"Запуск имитационной модели распределенного банка данных")
        print(f"{'='*60}")
        print(f"Параметры системы:")
        print(f"  - Всего заявок: {Config.TOTAL_REQUESTS}")
        print(f"  - Улучшенная система: {'ДА' if self.improved else 'НЕТ'}")
        print(f"  - Макс. размер очереди: {self.max_queue_size or 'не ограничен'}")
        print(f"{'='*60}")

        # Начальная инициализация
        start_time_wall = time.time()

        # Планирование первого события прибытия
        first_arrival = random.uniform(Config.GEN_MIN, Config.GEN_MAX)
        self._schedule_event(Event(first_arrival, 'ARRIVAL'))

        # Основной цикл событий
        iteration = 0
        while self.processed_requests < Config.TOTAL_REQUESTS and self.event_list:
            iteration += 1

            # Извлечение следующего события
            event = heapq.heappop(self.event_list)
            self.current_time = event.time
            self.stats['events_processed'] += 1

            if verbose and iteration % 50 == 0:
                print(f"Итерация {iteration}: t={self.current_time:.2f}, "
                      f"обработано {self.processed_requests}/{Config.TOTAL_REQUESTS}")

            # Обработка события
            if event.event_type == 'ARRIVAL':
                self._arrival_event()
            elif event.event_type == 'EV1_PRIMARY_END':
                self._ev1_primary_end_event(event.data)
            elif event.event_type == 'EV1_FINAL_END':
                self._ev1_final_end_event(event.data)
            elif event.event_type == 'CHANNEL_END':
                self._channel_end_event(event.data)
            elif event.event_type == 'EV2_PRIMARY_END':
                self._ev2_primary_end_event(event.data)
            elif event.event_type == 'EV2_FINAL_END':
                self._ev2_final_end_event(event.data)

            # Периодический сбор статистики
            if self.current_time - self.stats['last_stat_time'] > 100.0:
                self._collect_queue_stats()
                self.stats['last_stat_time'] = self.current_time

        # Финальный сбор статистики
        self._collect_queue_stats()

        # Расчет времени моделирования
        end_time_wall = time.time()
        simulation_time_wall = end_time_wall - start_time_wall

        print(f"{'='*60}")
        print(f"Моделирование завершено!")
        print(f"  - Модельное время: {self.current_time:.2f} сек")
        print(f"  - Реальное время: {simulation_time_wall:.2f} сек")
        print(f"  - Обработано событий: {self.stats['events_processed']}")
        print(f"  - Обработано заявок: {self.processed_requests}")
        print(f"  - Потеряно заявок: {self.lost_requests}")
        print(f"{'='*60}")

    def get_statistics(self) -> Dict:
        """Получить полную статистику по моделированию"""
        if not self.finished_requests:
            return {}

        # Времена пребывания в системе
        system_times = [r.total_time() for r in self.finished_requests]

        # Времена ожидания в очередях
        wait_times_q1 = [r.queue_times.get('Q1', 0) for r in self.finished_requests]
        wait_times_q2 = [r.queue_times.get('Q2', 0) for r in self.finished_requests if r.path == 'local']
        wait_times_q3 = [r.queue_times.get('Q3', 0) for r in self.finished_requests if r.path == 'remote']

        # Распределение по маршрутам
        local_count = sum(1 for r in self.finished_requests if r.path == 'local')
        remote_count = sum(1 for r in self.finished_requests if r.path == 'remote')

        # Коэффициенты загрузки приборов
        total_time = self.current_time
        utilizations = {}
        for dev_name, device in self.devices.items():
            if dev_name != 'SOURCE':
                utilizations[dev_name] = device.utilization(total_time)

        stats = {
            'total_time': self.current_time,
            'processed_requests': self.processed_requests,
            'lost_requests': self.lost_requests,
            'request_loss_prob': self.lost_requests / (self.processed_requests + self.lost_requests)
            if (self.processed_requests + self.lost_requests) > 0 else 0,

            # Статистика по очередям
            'queue_max': dict(self.stats['queue_max']),
            'queue_avg': dict(self.stats['queue_avg']),

            # Статистика по времени
            'system_time': {
                'min': min(system_times) if system_times else 0,
                'max': max(system_times) if system_times else 0,
                'avg': sum(system_times) / len(system_times) if system_times else 0,
                'std': np.std(system_times) if system_times else 0,
                'all': system_times
            },

            # Статистика по времени ожидания
            'wait_time_q1': {
                'min': min(wait_times_q1) if wait_times_q1 else 0,
                'max': max(wait_times_q1) if wait_times_q1 else 0,
                'avg': sum(wait_times_q1) / len(wait_times_q1) if wait_times_q1 else 0,
            },
            'wait_time_q2': {
                'min': min(wait_times_q2) if wait_times_q2 else 0,
                'max': max(wait_times_q2) if wait_times_q2 else 0,
                'avg': sum(wait_times_q2) / len(wait_times_q2) if wait_times_q2 else 0,
            },
            'wait_time_q3': {
                'min': min(wait_times_q3) if wait_times_q3 else 0,
                'max': max(wait_times_q3) if wait_times_q3 else 0,
                'avg': sum(wait_times_q3) / len(wait_times_q3) if wait_times_q3 else 0,
            },

            # Распределение заявок
            'path_distribution': {
                'local': local_count,
                'remote': remote_count,
                'local_percent': local_count / self.processed_requests * 100
                if self.processed_requests > 0 else 0,
            },

            # Загрузка приборов
            'device_utilization': utilizations,

            # Количественные показатели приборов
            'device_stats': {
                name: {
                    'processed': device.total_processed,
                    'busy_time': device.busy_time,
                    'utilization': device.utilization(total_time)
                }
                for name, device in self.devices.items() if name != 'SOURCE'
            }
        }

        return stats

    def print_statistics(self):
        """Вывод статистики в консоль"""
        stats = self.get_statistics()

        if not stats:
            print("Нет данных для отображения статистики")
            return

        print("\n" + "="*80)
        print("СТАТИСТИКА МОДЕЛИРОВАНИЯ")
        print("="*80)

        # Общая информация
        print(f"\n1. ОБЩАЯ ИНФОРМАЦИЯ:")
        print(f"   Общее модельное время: {stats['total_time']:.2f} сек")
        print(f"   Обработано заявок: {stats['processed_requests']}")
        print(f"   Потеряно заявок: {stats['lost_requests']}")
        print(f"   Вероятность потери: {stats['request_loss_prob']:.4f}")

        # Распределение по маршрутам
        print(f"\n2. РАСПРЕДЕЛЕНИЕ ЗАЯВОК:")
        dist = stats['path_distribution']
        print(f"   Локальная обработка (ЭВМ1): {dist['local']} ({dist['local_percent']:.1f}%)")
        print(f"   Удаленная обработка (ЭВМ2): {dist['remote']} ({100-dist['local_percent']:.1f}%)")

        # Статистика по очередям
        print(f"\n3. ХАРАКТЕРИСТИКИ ОЧЕРЕДЕЙ:")
        print(f"   {'Очередь':<10} {'Макс.длина':<12} {'Ср.длина':<12} {'Ср.время ожидания':<18}")
        print(f"   {'-'*10} {'-'*12} {'-'*12} {'-'*18}")

        queues = ['Q1', 'Q2', 'Q3']
        for q in queues:
            if q in stats['queue_max']:
                max_len = stats['queue_max'][q]
                avg_len = stats['queue_avg'][q]
                wait_key = f'wait_time_{q.lower()}'
                avg_wait = stats[wait_key]['avg'] if wait_key in stats else 0
                print(f"   {q:<10} {max_len:<12} {avg_len:<12.2f} {avg_wait:<18.2f}")

        # Время в системе
        sys_time = stats['system_time']
        print(f"\n4. ВРЕМЯ ПРЕБЫВАНИЯ В СИСТЕМЕ:")
        print(f"   Минимальное: {sys_time['min']:.2f} сек")
        print(f"   Максимальное: {sys_time['max']:.2f} сек")
        print(f"   Среднее: {sys_time['avg']:.2f} сек")
        print(f"   Среднеквадратичное отклонение: {sys_time['std']:.2f} сек")

        # Загрузка приборов
        print(f"\n5. ЗАГРУЗКА ПРИБОРОВ (коэффициент использования):")
        for dev_name, util in stats['device_utilization'].items():
            print(f"   {dev_name:<15}: {util:.3f}")

        print("="*80)

    def plot_results(self, save_path=None):
        """Построение графиков результатов"""
        stats = self.get_statistics()

        if not stats:
            print("Нет данных для построения графиков")
            return

        # Создание фигуры с несколькими подграфиками
        fig = plt.figure(figsize=(16, 10))
        fig.suptitle(f'Результаты имитационного моделирования распределенного банка данных\n'
                     f'{"(Улучшенная система - 2 прибора ЭВМ1-ок)" if self.improved else "(Базовая система)"}',
                     fontsize=14, fontweight='bold')

        # 1. Гистограмма времени пребывания в системе
        ax1 = plt.subplot(2, 3, 1)
        system_times = stats['system_time']['all']
        ax1.hist(system_times, bins=30, edgecolor='black', alpha=0.7, color=Config.COLORS['device'])
        ax1.set_xlabel('Время в системе (сек)')
        ax1.set_ylabel('Количество заявок')
        ax1.set_title('Распределение времени пребывания в системе')
        ax1.grid(True, alpha=0.3)

        # Добавление вертикальной линии для среднего значения
        avg_time = stats['system_time']['avg']
        ax1.axvline(avg_time, color='red', linestyle='--', linewidth=2,
                    label=f'Среднее: {avg_time:.1f} сек')
        ax1.legend()

        # 2. Динамика длин очередей
        ax2 = plt.subplot(2, 3, 2)
        colors = ['blue', 'green', 'red']
        for i, (q_name, q_data) in enumerate(self.stats['queue_lengths'].items()):
            if q_data:
                times, lengths = zip(*q_data)
                ax2.plot(times, lengths, label=f'Очередь {q_name}',
                         color=colors[i % len(colors)], linewidth=1.5)

        ax2.set_xlabel('Модельное время (сек)')
        ax2.set_ylabel('Длина очереди')
        ax2.set_title('Динамика изменения длин очередей')
        ax2.legend()
        ax2.grid(True, alpha=0.3)

        # 3. Столбчатая диаграмма максимальных длин очередей
        ax3 = plt.subplot(2, 3, 3)
        queue_names = list(stats['queue_max'].keys())
        max_lengths = [stats['queue_max'][q] for q in queue_names]
        avg_lengths = [stats['queue_avg'][q] for q in queue_names]

        x = np.arange(len(queue_names))
        width = 0.35

        ax3.bar(x - width/2, max_lengths, width, label='Максимальная',
                color='tomato', edgecolor='black')
        ax3.bar(x + width/2, avg_lengths, width, label='Средняя',
                color='lightblue', edgecolor='black')

        ax3.set_xlabel('Очередь')
        ax3.set_ylabel('Длина очереди')
        ax3.set_title('Максимальная и средняя длина очередей')
        ax3.set_xticks(x)
        ax3.set_xticklabels(queue_names)
        ax3.legend()
        ax3.grid(True, alpha=0.3, axis='y')

        # 4. Круговая диаграмма распределения заявок
        ax4 = plt.subplot(2, 3, 4)
        dist = stats['path_distribution']
        labels = ['Локальная обработка\n(ЭВМ1)', 'Удаленная обработка\n(ЭВМ2)']
        sizes = [dist['local'], dist['remote']]
        colors_pie = ['lightgreen', 'lightcoral']

        ax4.pie(sizes, labels=labels, colors=colors_pie, autopct='%1.1f%%',
                startangle=90, shadow=True, explode=(0.05, 0))
        ax4.set_title('Распределение заявок по маршрутам обработки')

        # 5. Коэффициенты загрузки приборов
        ax5 = plt.subplot(2, 3, 5)
        devices = list(stats['device_utilization'].keys())
        utilizations = [stats['device_utilization'][d] for d in devices]

        bars = ax5.bar(devices, utilizations, color='gold', edgecolor='black')
        ax5.set_xlabel('Прибор')
        ax5.set_ylabel('Коэффициент загрузки')
        ax5.set_title('Загрузка приборов системы')
        ax5.set_ylim(0, 1.1)
        ax5.grid(True, alpha=0.3, axis='y')

        # Добавление значений на столбцы
        for bar, util in zip(bars, utilizations):
            height = bar.get_height()
            ax5.text(bar.get_x() + bar.get_width()/2., height + 0.02,
                     f'{util:.3f}', ha='center', va='bottom', fontsize=9)

        # 6. Сравнение времени ожидания в очередях
        ax6 = plt.subplot(2, 3, 6)
        wait_data = []
        wait_labels = []

        for q in ['q1', 'q2', 'q3']:
            wait_key = f'wait_time_{q}'
            if wait_key in stats and stats[wait_key]['avg'] > 0:
                wait_data.append(stats[wait_key]['avg'])
                wait_labels.append(f'Очередь {q.upper()}')

        if wait_data:
            bars_wait = ax6.bar(wait_labels, wait_data,
                                color=['skyblue', 'lightgreen', 'salmon'],
                                edgecolor='black')
            ax6.set_xlabel('Очередь')
            ax6.set_ylabel('Среднее время ожидания (сек)')
            ax6.set_title('Среднее время ожидания в очередях')
            ax6.grid(True, alpha=0.3, axis='y')

            # Добавление значений на столбцы
            for bar, val in zip(bars_wait, wait_data):
                height = bar.get_height()
                ax6.text(bar.get_x() + bar.get_width()/2., height + max(wait_data)*0.01,
                         f'{val:.1f}', ha='center', va='bottom', fontsize=9)

        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Графики сохранены в файл: {save_path}")

        plt.show()

    def plot_queue_length_distribution(self, save_path=None):
        """Построение распределения длин очередей"""
        if not self.stats['queue_lengths']:
            print("Нет данных о длинах очередей")
            return

        fig, axes = plt.subplots(1, 3, figsize=(15, 5))
        fig.suptitle('Распределение длин очередей', fontsize=14, fontweight='bold')

        for idx, (q_name, q_data) in enumerate(self.stats['queue_lengths'].items()):
            if idx >= 3:
                break

            ax = axes[idx]
            if q_data:
                # Извлечение только длин очередей
                times, lengths = zip(*q_data)

                # Построение гистограммы
                max_len = max(lengths)
                bins = range(0, max_len + 2)
                ax.hist(lengths, bins=bins, edgecolor='black', alpha=0.7,
                        color=Config.COLORS['queue'], density=True)

                # Расчет и отображение вероятностей
                total_samples = len(lengths)
                unique_lengths = sorted(set(lengths))
                probs = []
                for l in unique_lengths:
                    prob = lengths.count(l) / total_samples
                    probs.append(prob)

                # Отображение наиболее вероятных длин
                if len(unique_lengths) > 0:
                    max_prob_idx = probs.index(max(probs))
                    most_prob_len = unique_lengths[max_prob_idx]
                    ax.axvline(most_prob_len, color='red', linestyle='--',
                               linewidth=1, alpha=0.7,
                               label=f'Наиболее вероятно: {most_prob_len}')

                ax.set_xlabel(f'Длина очереди {q_name}')
                ax.set_ylabel('Вероятность')
                ax.set_title(f'Очередь {q_name}\nМакс: {max_len}, Ср: {self.stats["queue_avg"][q_name]:.2f}')
                ax.legend()
                ax.grid(True, alpha=0.3)

        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')

        plt.show()


# ============================================================================
# ФУНКЦИИ ДЛЯ ПРОВЕДЕНИЯ ЭКСПЕРИМЕНТОВ
# ============================================================================

def run_single_experiment(improved=False, seed=None, verbose=False):
    """Запуск одиночного эксперимента"""
    if seed is not None:
        random.seed(seed)

    print(f"\n{'='*60}")
    print(f"Эксперимент с seed={seed}")
    print(f"{'='*60}")

    model = DistributedDBModel(improved_system=improved)
    model.run(verbose=verbose)
    model.print_statistics()

    return model

def run_multiple_experiments(n_runs=10, improved=False):
    """Запуск серии экспериментов для получения статистически устойчивых результатов"""
    print(f"\n{'='*80}")
    print(f"ЗАПУСК СЕРИИ ИЗ {n_runs} ЭКСПЕРИМЕНТОВ")
    print(f"Улучшенная система: {'ДА' if improved else 'НЕТ'}")
    print(f"{'='*80}")

    all_stats = []
    seeds = list(range(1, n_runs + 1))

    for seed in seeds:
        print(f"\nЭксперимент {seed}/{n_runs} (seed={seed})...")
        random.seed(seed)

        model = DistributedDBModel(improved_system=improved)
        model.run(verbose=False)

        stats = model.get_statistics()
        all_stats.append(stats)

    # Агрегация результатов
    aggregated = aggregate_statistics(all_stats)
    print_aggregated_results(aggregated, improved)

    return all_stats, aggregated

def aggregate_statistics(all_stats):
    """Агрегация статистики по нескольким экспериментам"""
    if not all_stats:
        return {}

    aggregated = {
        'system_time_avg': [],
        'queue_max_avg': defaultdict(list),
        'queue_avg_avg': defaultdict(list),
        'device_utilization_avg': defaultdict(list),
        'path_local_percent': [],
        'total_time': [],
    }

    for stats in all_stats:
        if not stats:
            continue

        # Время в системе
        aggregated['system_time_avg'].append(stats['system_time']['avg'])

        # Очереди
        for q_name, max_len in stats['queue_max'].items():
            aggregated['queue_max_avg'][q_name].append(max_len)

        for q_name, avg_len in stats['queue_avg'].items():
            aggregated['queue_avg_avg'][q_name].append(avg_len)

        # Загрузка приборов
        for dev_name, util in stats['device_utilization'].items():
            aggregated['device_utilization_avg'][dev_name].append(util)

        # Распределение заявок
        aggregated['path_local_percent'].append(stats['path_distribution']['local_percent'])

        # Общее время
        aggregated['total_time'].append(stats['total_time'])

    # Расчет средних значений и доверительных интервалов
    result = {
        'system_time': {
            'mean': np.mean(aggregated['system_time_avg']),
            'std': np.std(aggregated['system_time_avg']),
            'ci_low': np.percentile(aggregated['system_time_avg'], 2.5),
            'ci_high': np.percentile(aggregated['system_time_avg'], 97.5),
        },
        'queue_max': {},
        'queue_avg': {},
        'device_utilization': {},
        'path_distribution': {
            'local_percent_mean': np.mean(aggregated['path_local_percent']),
            'local_percent_std': np.std(aggregated['path_local_percent']),
        },
        'total_time_mean': np.mean(aggregated['total_time']),
    }

    # Очереди
    for q_name in aggregated['queue_max_avg']:
        result['queue_max'][q_name] = {
            'mean': np.mean(aggregated['queue_max_avg'][q_name]),
            'std': np.std(aggregated['queue_max_avg'][q_name]),
        }

    for q_name in aggregated['queue_avg_avg']:
        result['queue_avg'][q_name] = {
            'mean': np.mean(aggregated['queue_avg_avg'][q_name]),
            'std': np.std(aggregated['queue_avg_avg'][q_name]),
        }

    # Загрузка приборов
    for dev_name in aggregated['device_utilization_avg']:
        result['device_utilization'][dev_name] = {
            'mean': np.mean(aggregated['device_utilization_avg'][dev_name]),
            'std': np.std(aggregated['device_utilization_avg'][dev_name]),
        }

    return result

def print_aggregated_results(aggregated, improved):
    """Вывод агрегированных результатов"""
    print(f"\n{'='*80}")
    print(f"АГРЕГИРОВАННЫЕ РЕЗУЛЬТАТЫ ({'Улучшенная' if improved else 'Базовая'} система)")
    print(f"{'='*80}")

    print(f"\n1. ВРЕМЯ ПРЕБЫВАНИЯ В СИСТЕМЕ:")
    sys_time = aggregated['system_time']
    print(f"   Среднее: {sys_time['mean']:.2f} ± {sys_time['std']:.2f} сек")
    print(f"   95% доверительный интервал: [{sys_time['ci_low']:.2f}, {sys_time['ci_high']:.2f}] сек")

    print(f"\n2. МАКСИМАЛЬНЫЕ ДЛИНЫ ОЧЕРЕДЕЙ:")
    for q_name, q_stats in aggregated['queue_max'].items():
        print(f"   {q_name}: {q_stats['mean']:.1f} ± {q_stats['std']:.1f}")

    print(f"\n3. СРЕДНИЕ ДЛИНЫ ОЧЕРЕДЕЙ:")
    for q_name, q_stats in aggregated['queue_avg'].items():
        print(f"   {q_name}: {q_stats['mean']:.2f} ± {q_stats['std']:.2f}")

    print(f"\n4. РАСПРЕДЕЛЕНИЕ ЗАЯВОК:")
    path = aggregated['path_distribution']
    print(f"   Локальная обработка: {path['local_percent_mean']:.1f}% ± {path['local_percent_std']:.1f}%")

    print(f"\n5. ЗАГРУЗКА ПРИБОРОВ:")
    for dev_name, util_stats in aggregated['device_utilization'].items():
        print(f"   {dev_name:<15}: {util_stats['mean']:.3f} ± {util_stats['std']:.3f}")

    print(f"\n6. ОБЩЕЕ МОДЕЛЬНОЕ ВРЕМЯ:")
    print(f"   Среднее: {aggregated['total_time_mean']:.2f} сек")

    print(f"{'='*80}")

def determine_queue_capacity(target_loss_prob=0.001, max_capacity=100):
    """Определение необходимой емкости накопителей"""
    print(f"\n{'='*80}")
    print(f"ОПРЕДЕЛЕНИЕ ЕМКОСТИ НАКОПИТЕЛЕЙ ДЛЯ ВЕРОЯТНОСТИ ПОТЕРИ < {target_loss_prob}")
    print(f"{'='*80}")

    capacities = list(range(5, max_capacity + 1, 5))
    results = []

    for capacity in capacities:
        print(f"\nТестирование емкости: {capacity}")

        loss_probs = []
        for seed in range(1, 6):  # 5 прогонов для каждой емкости
            random.seed(seed)
            model = DistributedDBModel(improved_system=False, max_queue_size=capacity)
            model.run(verbose=False)
            stats = model.get_statistics()
            loss_prob = stats.get('request_loss_prob', 0)
            loss_probs.append(loss_prob)

        avg_loss_prob = np.mean(loss_probs)
        print(f"  Средняя вероятность потери: {avg_loss_prob:.6f}")

        results.append({
            'capacity': capacity,
            'loss_prob': avg_loss_prob,
            'meets_target': avg_loss_prob < target_loss_prob
        })

        if avg_loss_prob < target_loss_prob:
            print(f"  ✓ Цель достигнута!")
            break

    # Поиск минимальной емкости, удовлетворяющей требованию
    suitable_capacities = [r for r in results if r['meets_target']]
    if suitable_capacities:
        min_capacity = min(suitable_capacities, key=lambda x: x['capacity'])
        print(f"\n{'='*80}")
        print(f"РЕКОМЕНДУЕМАЯ ЕМКОСТЬ НАКОПИТЕЛЕЙ:")
        print(f"  Минимальная емкость, обеспечивающая P(потери) < {target_loss_prob}: {min_capacity['capacity']}")
        print(f"  Соответствующая вероятность потери: {min_capacity['loss_prob']:.6f}")
    else:
        print(f"\nНе удалось достичь целевой вероятности потери даже при емкости {max_capacity}")

    return results


# ============================================================================
# ОСНОВНАЯ ФУНКЦИЯ
# ============================================================================

def main():
    """Основная функция программы"""
    print("КУРСОВАЯ РАБОТА ПО МОДЕЛИРОВАНИЮ СИСТЕМ МАССОВОГО ОБСЛУЖИВАНИЯ")
    print("Тема: Распределенный банк данных системы сбора информации")
    print("Вариант 18")
    print("="*80)

    # Параметры запуска
    SINGLE_EXPERIMENT = True        # Запустить одиночный эксперимент
    MULTIPLE_EXPERIMENTS = False    # Запустить серию экспериментов
    DETERMINE_CAPACITY = False      # Определить емкость накопителей
    IMPROVED_SYSTEM = False         # Использовать улучшенную систему
    SEED = 42                       # Seed для воспроизводимости
    VERBOSE = False                 # Подробный вывод

    if SINGLE_EXPERIMENT:
        # Одиночный эксперимент
        model = run_single_experiment(
            improved=IMPROVED_SYSTEM,
            seed=SEED,
            verbose=VERBOSE
        )

        # Построение графиков
        model.plot_results(save_path=f'results_{"improved" if IMPROVED_SYSTEM else "base"}.png')
        model.plot_queue_length_distribution(save_path=f'queues_{"improved" if IMPROVED_SYSTEM else "base"}.png')

        # Дополнительная информация
        print("\nПервые 10 обработанных заявок:")
        for i, req in enumerate(model.finished_requests[:10]):
            print(f"  {req}")

    if MULTIPLE_EXPERIMENTS:
        # Серия экспериментов для базовой системы
        print("\n" + "="*80)
        print("БАЗОВАЯ СИСТЕМА (один прибор ЭВМ1-ок)")
        print("="*80)
        base_stats, base_aggregated = run_multiple_experiments(n_runs=10, improved=False)

        # Серия экспериментов для улучшенной системы
        print("\n" + "="*80)
        print("УЛУЧШЕННАЯ СИСТЕМА (два прибора ЭВМ1-ок)")
        print("="*80)
        improved_stats, improved_aggregated = run_multiple_experiments(n_runs=10, improved=True)

        # Сравнительный анализ
        print("\n" + "="*80)
        print("СРАВНИТЕЛЬНЫЙ АНАЛИЗ РЕЗУЛЬТАТОВ")
        print("="*80)

        print(f"\nСНИЖЕНИЕ СРЕДНЕГО ВРЕМЕНИ В СИСТЕМЕ:")
        base_time = base_aggregated['system_time']['mean']
        improved_time = improved_aggregated['system_time']['mean']
        reduction = (base_time - improved_time) / base_time * 100
        print(f"  Базовая система: {base_time:.1f} сек")
        print(f"  Улучшенная система: {improved_time:.1f} сек")
        print(f"  Снижение на: {reduction:.1f}%")

        print(f"\nСНИЖЕНИЕ МАКСИМАЛЬНЫХ ДЛИН ОЧЕРЕДЕЙ:")
        for q_name in ['Q2', 'Q3']:
            if q_name in base_aggregated['queue_max'] and q_name in improved_aggregated['queue_max']:
                base_max = base_aggregated['queue_max'][q_name]['mean']
                improved_max = improved_aggregated['queue_max'][q_name]['mean']
                reduction = (base_max - improved_max) / base_max * 100
                print(f"  Очередь {q_name}: {base_max:.0f} → {improved_max:.0f} (-{reduction:.1f}%)")

    if DETERMINE_CAPACITY:
        # Определение необходимой емкости накопителей
        determine_queue_capacity(target_loss_prob=0.001, max_capacity=100)


# ============================================================================
# ТОЧКА ВХОДА
# ============================================================================

if __name__ == "__main__":
    # Установка seed для воспроизводимости результатов
    random.seed(42)

    # Запуск основной функции
    main()
