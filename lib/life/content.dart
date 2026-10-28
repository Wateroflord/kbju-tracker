// Встроенный контент: привычки, упражнения, программы, советы, покупки, напоминания.

import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

import 'models.dart';

// ---------------- Привычки ----------------

const defaultHabits = <Habit>[
  Habit(id: 'sleep', title: 'Сон 7–9 часов', period: HabitPeriod.daily, auto: HabitAuto.sleep, icon: 'sleep', builtin: true),
  Habit(id: 'steps', title: 'Шаги по цели', period: HabitPeriod.daily, auto: HabitAuto.steps, icon: 'walk', builtin: true),
  Habit(id: 'food', title: 'Калории в норме', period: HabitPeriod.daily, auto: HabitAuto.food, icon: 'food', builtin: true),
  Habit(id: 'water', title: 'Вода по норме', period: HabitPeriod.daily, auto: HabitAuto.water, icon: 'water', builtin: true),
  Habit(id: 'care_am', title: 'Уход утром: умывание, крем, SPF', period: HabitPeriod.daily, icon: 'sun', builtin: true),
  Habit(id: 'care_pm', title: 'Уход вечером: умывание, крем', period: HabitPeriod.daily, icon: 'moon', builtin: true),
  Habit(id: 'learn', title: 'Язык: дневная цель', period: HabitPeriod.daily, auto: HabitAuto.learn, icon: 'book', builtin: true),
  Habit(id: 'mood', title: 'Отметить настроение', period: HabitPeriod.daily, auto: HabitAuto.mood, icon: 'mood', builtin: true, enabled: false),
  Habit(id: 'mind', title: 'Дыхание или медитация', period: HabitPeriod.daily, auto: HabitAuto.mind, icon: 'spa', builtin: true, enabled: false),
  Habit(id: 'teeth', title: 'Зубы 2 раза + нить', period: HabitPeriod.daily, icon: 'teeth', builtin: true),
  Habit(id: 'no_screen', title: 'Час без экрана перед сном', period: HabitPeriod.daily, icon: 'phone_off', builtin: true),
  Habit(id: 'workouts', title: '3 тренировки', period: HabitPeriod.weekly, auto: HabitAuto.workouts, icon: 'gym', builtin: true),
  Habit(id: 'weigh', title: 'Взвеситься', period: HabitPeriod.weekly, auto: HabitAuto.weigh, icon: 'scale', builtin: true),
  Habit(id: 'nails', title: 'Подстричь ногти', period: HabitPeriod.weekly, icon: 'nails', builtin: true),
  Habit(id: 'pillow', title: 'Сменить наволочку', period: HabitPeriod.weekly, icon: 'bed', builtin: true),
  Habit(id: 'mealprep', title: 'Приготовить еду на 2–3 дня', period: HabitPeriod.weekly, icon: 'kitchen', builtin: true),
  Habit(id: 'haircut', title: 'Стрижка (раз в 3–6 недель)', period: HabitPeriod.monthly, icon: 'cut', builtin: true),
  Habit(id: 'wardrobe', title: 'Разобрать шкаф', period: HabitPeriod.monthly, icon: 'shirt', builtin: true),
  Habit(id: 'compare', title: 'Сравнить фото и вес', period: HabitPeriod.monthly, icon: 'photo', builtin: true),
];

IconData habitIcon(String key) => switch (key) {
      'sleep' => Icons.bedtime_outlined,
      'walk' => Icons.directions_walk,
      'food' => Icons.restaurant_outlined,
      'water' => Icons.water_drop_outlined,
      'sun' => Icons.wb_sunny_outlined,
      'moon' => Icons.nightlight_outlined,
      'teeth' => Icons.clean_hands_outlined,
      'phone_off' => Icons.phonelink_erase_outlined,
      'gym' => Icons.fitness_center,
      'scale' => Icons.monitor_weight_outlined,
      'nails' => Icons.content_cut,
      'bed' => Icons.bed_outlined,
      'kitchen' => Icons.kitchen_outlined,
      'cut' => Icons.face_retouching_natural,
      'shirt' => Icons.checkroom_outlined,
      'photo' => Icons.photo_camera_outlined,
      'face' => Icons.face_outlined,
      'spa' => Icons.spa_outlined,
      'posture' => Icons.accessibility_new,
      'book' => Icons.menu_book_outlined,
      'mood' => Icons.sentiment_satisfied_outlined,
      _ => Icons.check_circle_outline,
    };

/// Иконки, из которых можно выбрать для своей привычки.
const customHabitIcons = ['check', 'book', 'spa', 'face', 'posture', 'walk', 'water', 'sun', 'moon', 'gym'];

String periodTitle(HabitPeriod p) => switch (p) {
      HabitPeriod.daily => tr('Каждый день'),
      HabitPeriod.weekly => tr('Каждую неделю'),
      HabitPeriod.monthly => tr('Раз в месяц'),
    };

// ---------------- Упражнения ----------------

const builtinExercises = <Exercise>[
  Exercise(
    id: 'squat',
    name: 'Присед со штангой',
    technique: 'Штанга на трапеции, стопы на ширине плеч. Садись, отводя таз назад, колени по линии носков, '
        'спина прямая. Опускайся до параллели бедра с полом.',
    easier: 'Присед с гантелью у груди (гоблет).',
  ),
  Exercise(
    id: 'bench',
    name: 'Жим штанги лёжа',
    technique: 'Лопатки сведены, стопы упираются в пол. Опускай гриф к нижней части груди, '
        'локти под углом ~45° к корпусу, жми вверх.',
    easier: 'Жим гантелей лёжа или отжимания.',
  ),
  Exercise(
    id: 'lat_pulldown',
    name: 'Тяга верхнего блока',
    technique: 'Хват чуть шире плеч. Тяни рукоять к верху груди, сводя лопатки, корпус чуть отклонён назад. '
        'Не раскачивайся.',
    easier: 'Меньший вес и медленное опускание.',
  ),
  Exercise(
    id: 'db_press_seated',
    name: 'Жим гантелей сидя',
    technique: 'Спина прижата к скамье. Гантели от уровня ушей выжимай вверх, не стукая ими. '
        'Не прогибай поясницу.',
    easier: 'Поочерёдный жим одной рукой.',
  ),
  Exercise(
    id: 'plank',
    name: 'Планка',
    technique: 'Упор на предплечья, тело одной прямой линией от пяток до головы. '
        'Напряги пресс и ягодицы, не проваливай поясницу.',
    easier: 'Планка с колен, 20 секунд.',
    bodyweight: true,
    timed: true,
  ),
  Exercise(
    id: 'rdl',
    name: 'Румынская тяга',
    technique: 'Колени слегка согнуты. Наклоняйся, отводя таз назад, штанга скользит по бёдрам. '
        'Спина прямая, почувствуй растяжение задней поверхности бедра.',
    easier: 'С гантелями и меньшей амплитудой.',
  ),
  Exercise(
    id: 'incline_db',
    name: 'Жим гантелей на наклонной',
    technique: 'Скамья под 30°. Опускай гантели к верху груди, локти под ~45°, выжимай вверх по дуге.',
    easier: 'Меньший угол скамьи и вес.',
  ),
  Exercise(
    id: 'db_row',
    name: 'Тяга гантели в наклоне',
    technique: 'Рука и колено на скамье, спина параллельна полу. Тяни гантель к поясу локтем вдоль корпуса.',
    easier: 'Меньший вес, пауза вверху.',
  ),
  Exercise(
    id: 'lunges_legpress',
    name: 'Выпады или жим ногами',
    technique: 'Выпады: шаг вперёд, оба колена под 90°, корпус прямо. Жим ногами: стопы на ширине плеч, '
        'не отрывай таз от сиденья и не выпрямляй колени до щелчка.',
    easier: 'Выпады без веса.',
  ),
  Exercise(
    id: 'biceps',
    name: 'Сгибания на бицепс',
    technique: 'Локти прижаты к корпусу. Поднимай гантели без раскачки, медленно опускай.',
    easier: 'Меньший вес, поочерёдно.',
  ),
  Exercise(
    id: 'triceps',
    name: 'Разгибания на трицепс',
    technique: 'На блоке: локти прижаты, разгибай руки до конца вниз, медленно возвращай.',
    easier: 'Обратные отжимания от скамьи с согнутыми ногами.',
  ),
  Exercise(
    id: 'pushups',
    name: 'Отжимания',
    technique: 'Руки чуть шире плеч, тело прямое. Опускайся грудью почти до пола, локти под ~45°.',
    easier: 'От скамьи или с колен.',
    bodyweight: true,
  ),
  Exercise(
    id: 'pullups',
    name: 'Подтягивания',
    technique: 'Хват чуть шире плеч. Тянись грудью к перекладине, сводя лопатки, без рывков. '
        'Опускайся до почти прямых рук.',
    easier: 'Негативы: запрыгни наверх и медленно опускайся 3–5 секунд.',
    bodyweight: true,
  ),
  Exercise(
    id: 'bw_squat',
    name: 'Приседания',
    technique: 'Стопы на ширине плеч, таз назад, колени по линии носков, пятки на полу. '
        'Опускайся до параллели или ниже.',
    easier: 'Приседания до стула. Когда легко — болгарские выпады.',
    bodyweight: true,
  ),
  Exercise(
    id: 'reverse_lunge',
    name: 'Выпады назад',
    technique: 'Шаг назад, опускайся до касания коленом пола почти, переднее колено над стопой. '
        'Считай повторы на каждую ногу.',
    easier: 'Меньшая глубина, держись за опору.',
    bodyweight: true,
  ),
  Exercise(
    id: 'glute_bridge',
    name: 'Ягодичный мостик',
    technique: 'Лёжа на спине, стопы ближе к тазу. Поднимай таз, сжимая ягодицы, пауза 1 секунда вверху.',
    easier: 'На двух ногах. Сложнее — на одной ноге.',
    bodyweight: true,
  ),
];

const builtinPrograms = <Program>[
  Program(
    id: 'gym_ab',
    title: 'Зал: А / Б',
    desc: 'Три тренировки на всё тело, чередуй А и Б.',
    days: [
      WorkoutDay(id: 'A', title: 'Тренировка А', exercises: [
        PlanExercise('squat', 3, 6, 10),
        PlanExercise('bench', 3, 6, 10),
        PlanExercise('lat_pulldown', 3, 8, 12),
        PlanExercise('db_press_seated', 2, 10, 12),
        PlanExercise('plank', 3, 30, 60),
      ]),
      WorkoutDay(id: 'B', title: 'Тренировка Б', exercises: [
        PlanExercise('rdl', 3, 8, 10),
        PlanExercise('incline_db', 3, 8, 12),
        PlanExercise('db_row', 3, 8, 12),
        PlanExercise('lunges_legpress', 3, 10, 12),
        PlanExercise('biceps', 2, 10, 15),
        PlanExercise('triceps', 2, 10, 15),
      ]),
    ],
  ),
  Program(
    id: 'bodyweight',
    title: 'Свой вес',
    desc: 'Дома или на площадке, нужен только турник.',
    days: [
      WorkoutDay(id: 'BW', title: 'Свой вес', exercises: [
        PlanExercise('pushups', 3, 0, 0),
        PlanExercise('pullups', 3, 0, 0),
        PlanExercise('bw_squat', 3, 15, 25),
        PlanExercise('reverse_lunge', 3, 10, 15),
        PlanExercise('glute_bridge', 3, 15, 20),
        PlanExercise('plank', 3, 30, 60),
      ]),
    ],
  ),
];

// ---------------- Совет дня ----------------

const dailyTips = <String>[
  'Добавь белок в каждый приём пищи: мясо, рыба, яйца, творог, греческий йогурт, бобовые.',
  'Половина тарелки — овощи или фрукты: больше сытости за меньшие калории.',
  'Сладкие напитки — главный скрытый источник калорий. Замени их на воду, чай или zero.',
  'Готовь еду на 2–3 дня вперёд — так проще не сорваться на фастфуд.',
  'Правило 80/20: 80% еды простой и полезной, 20% — что хочется.',
  'После еды пройдись 10–15 минут — это помогает пищеварению.',
  '8 км — это 10–11 тысяч шагов. Набирай кусками в течение дня.',
  'Выходи на остановку раньше и поднимайся по лестнице — шаги набираются сами.',
  'Слушай подкасты на прогулке — и ходьба станет отдыхом.',
  'Каждую неделю делай на тренировке чуть больше: +1 повтор или +2,5 кг.',
  'Техника важнее веса. Сними подход на видео и сравни с эталоном.',
  'Разминка 5–10 минут перед тренировкой снижает риск травмы.',
  'Острая боль в суставе — сигнал остановиться и заменить упражнение.',
  'Отдыхай между тяжёлыми подходами 1,5–3 минуты.',
  'Ложись и вставай в одно время даже в выходные — разница не больше часа.',
  'Утром выйди на дневной свет на 10–15 минут — вечером будет легче заснуть.',
  'Кофе и энергетики — не позже чем за 8 часов до сна.',
  'В спальне должно быть темно, тихо и прохладно, около 18–20 °C.',
  'Не ешь плотно за 2–3 часа до сна.',
  'Меняй наволочку раз в неделю — это заметно на коже лица.',
  'SPF каждое утро даёт для кожи больше, чем дорогие сыворотки.',
  'Не дави прыщи и не три лицо скрабами — так остаются следы.',
  'Новое средство для кожи вводи по одному раз в 2 недели.',
  'Ниацинамид вечером уменьшает жирный блеск и покраснения.',
  'Шампунь наноси на кожу головы, а кондиционер — только на длину.',
  'Мой голову тёплой, а не горячей водой: горячая сушит кожу.',
  'Стрижка каждые 3–6 недель — один из самых заметных апгрейдов внешности.',
  'Антиперспирант лучше наносить вечером на чистую сухую кожу.',
  'Аромат: 2–3 пшика, не больше.',
  'Чисти язык скребком — это главный секрет свежего дыхания.',
  'Профессиональная чистка зубов раз в 6–12 месяцев снимает налёт от кофе и чая.',
  'Правило 20-20-20: каждые 20 минут смотри 20 секунд на 20 футов (~6 м) вдаль.',
  'Монитор на уровне глаз и перерыв каждый час — осанка скажет спасибо.',
  'Размер важнее бренда: простая вещь по фигуре выглядит лучше дорогой и мешковатой.',
  'Шов на плече футболки должен быть на краю плеча.',
  'Чистая обувь — на неё смотрят чаще, чем кажется.',
  'Одна хорошая куртка на сезон лучше трёх дешёвых.',
  'Алкоголь ухудшает сон, восстановление и кожу — держи его по минимуму.',
  'Взвешивайся утром натощак — так цифры честнее.',
  'Сравнивай фото раз в месяц: в зеркале изменения не видно, на фото — видно.',
];

String tipOfDay(DateTime d) {
  final start = DateTime(d.year, 1, 1);
  final day = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(start.year, 1, 1)).inDays;
  return tr(dailyTips[(day + d.year) % dailyTips.length]);
}

// ---------------- Список покупок ----------------

const defaultShopping = <ShopItem>[
  ShopItem(id: 'cleanser', category: 'Кожа', name: 'Гель для умывания CeraVe, 236 мл', pricePln: 45.49, note: 'всем, особенно жирная кожа'),
  ShopItem(id: 'moist', category: 'Кожа', name: 'Крем CeraVe с церамидами, 52 мл', pricePln: 47.42, note: 'всем'),
  ShopItem(id: 'spf', category: 'Кожа', name: 'La Roche-Posay Anthelios SPF 50+, 50 мл', pricePln: 89.99, note: 'всем, не блестит'),
  ShopItem(id: 'niacin', category: 'Кожа', name: 'The Ordinary Niacinamide 10% + Zinc 1%, 30 мл', pricePln: 25, note: 'жирный блеск и поры'),
  ShopItem(id: 'nizoral', category: 'Волосы', name: 'Шампунь Nizoral, 60 мл', pricePln: 35.69, note: 'только при перхоти, 1–2 раза в неделю'),
  ShopItem(id: 'trimmer', category: 'Бритьё', name: 'Триммер Philips OneBlade 360', pricePln: 128, pricePlnMax: 166, note: 'борода, щетина, бритьё'),
  ShopItem(id: 'floss', category: 'Гигиена', name: 'Зубная нить или ёршики', pricePln: 0),
  ShopItem(id: 'tongue', category: 'Гигиена', name: 'Скребок для языка', pricePln: 0),
  ShopItem(id: 'lipbalm', category: 'Гигиена', name: 'Гигиеническая помада', pricePln: 0),
  ShopItem(id: 'nailfile', category: 'Гигиена', name: 'Пилка для ногтей', pricePln: 0),
  ShopItem(id: 'lint', category: 'Одежда', name: 'Машинка для катышков', pricePln: 0),
  ShopItem(id: 'bottle', category: 'Разное', name: 'Бутылка для воды', pricePln: 0),
];

/// Примерный курс для перевода цен в доллары.
const plnPerUsd = 3.6;

// ---------------- Напоминания ----------------

const defaultReminders = <Reminder>[
  Reminder(id: 'water', title: 'Вода', body: 'Выпей стакан воды и отметь в приложении', hour: 12, minute: 0),
  Reminder(id: 'care_am', title: 'Уход утром', body: 'Умывание, крем, SPF', hour: 8, minute: 0),
  Reminder(id: 'care_pm', title: 'Уход вечером', body: 'Умывание и крем перед сном', hour: 22, minute: 0),
  Reminder(id: 'workout', title: 'Тренировка', body: 'Сегодня по плану тренировка', hour: 18, minute: 0, fromProgram: true),
  Reminder(id: 'learn', title: 'Язык', body: 'Пора позаниматься: карточки и тест ждут', hour: 19, minute: 0),
  Reminder(id: 'bedtime', title: 'Пора спать', body: 'Отложи телефон — через час отбой', hour: 22, minute: 30),
  Reminder(id: 'weigh', title: 'Взвешивание', body: 'Взвесься утром натощак и запиши вес', hour: 8, minute: 0, weekdays: [1]),
];
