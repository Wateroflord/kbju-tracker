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
  // ---- добавлены для программ «Фулл бади», «Верх / Низ», «Жим / Тяга / Ноги», «Гантели дома», «Кардио дома» ----
  Exercise(
    id: 'deadlift',
    name: 'Становая тяга',
    technique: 'Штанга над серединой стопы, хват чуть шире ног. Спина прямая, лопатки сведены. Поднимай штангу, разгибая ноги и таз одновременно, гриф идёт вдоль ног. Опускай так же, не округляя спину.',
    easier: 'Румынская тяга с гантелями или тяга с плинтов (штанга выше от пола).',
  ),
  Exercise(
    id: 'bb_row',
    name: 'Тяга штанги в наклоне',
    technique: 'Наклонись вперёд примерно до 45°, спина прямая, колени слегка согнуты. Тяни штангу к низу живота, сводя лопатки, и медленно опускай.',
    easier: 'Тяга гантели в наклоне с опорой на скамью.',
  ),
  Exercise(
    id: 'goblet_squat',
    name: 'Гоблет-присед',
    technique: 'Держи гантель вертикально у груди. Садись между коленями, локти внутри коленей, спина прямая, пятки на полу.',
    easier: 'Приседания без веса до стула.',
  ),
  Exercise(
    id: 'dips',
    name: 'Отжимания на брусьях',
    technique: 'Упор на прямых руках, корпус чуть наклонён вперёд. Опускайся, пока плечо не станет параллельно полу, и выжимай себя вверх без рывков.',
    easier: 'Обратные отжимания от скамьи или брусья в гравитроне.',
    bodyweight: true,
  ),
  Exercise(
    id: 'cable_row',
    name: 'Тяга горизонтального блока',
    technique: 'Сядь прямо, колени слегка согнуты. Тяни рукоять к животу, сводя лопатки и не откидываясь назад. Медленно возвращай вперёд.',
    easier: 'Меньший вес, пауза 1 секунда у живота.',
  ),
  Exercise(
    id: 'lateral_raise',
    name: 'Разведения гантелей в стороны',
    technique: 'Стоя, гантели у бёдер, локти чуть согнуты. Поднимай руки в стороны до уровня плеч, не помогая корпусом, и медленно опускай.',
    easier: 'Лёгкие гантели, по одной руке.',
  ),
  Exercise(
    id: 'calf_raise',
    name: 'Подъёмы на носки',
    technique: 'Носки на краю ступеньки или платформы. Поднимайся как можно выше, пауза вверху, опускай пятки ниже уровня ступеньки.',
    easier: 'Без веса, на полу, держась за опору.',
  ),
  Exercise(
    id: 'hanging_leg_raise',
    name: 'Подъём ног в висе',
    technique: 'Повисни на турнике, корпус неподвижен. Поднимай ноги до уровня таза или выше, подкручивая таз, и медленно опускай без раскачки.',
    easier: 'Подъём согнутых коленей в висе или лёжа на полу.',
    bodyweight: true,
  ),
  Exercise(
    id: 'leg_curl',
    name: 'Сгибания ног в тренажёре',
    technique: 'Валик над пятками, таз прижат к сиденью. Сгибай ноги до конца и медленно разгибай, не бросая вес.',
    easier: 'Меньший вес. Дома — ягодичный мостик на одной ноге.',
  ),
  Exercise(
    id: 'face_pull',
    name: 'Тяга каната к лицу',
    technique: 'Канат на блоке на уровне лица. Тяни концы каната к лицу, разводя руки и локти в стороны, сожми лопатки. Полезно для плеч и осанки.',
    easier: 'С резиновой лентой или меньший вес.',
  ),
  Exercise(
    id: 'hammer_curl',
    name: 'Молотки с гантелями',
    technique: 'Ладони смотрят друг на друга, локти прижаты. Поднимай гантели без раскачки и медленно опускай.',
    easier: 'Меньший вес, поочерёдно.',
  ),
  Exercise(
    id: 'machine_chest_press',
    name: 'Жим от груди в тренажёре',
    technique: 'Рукояти на уровне середины груди, спина прижата, лопатки сведены. Выжимай вперёд, не выпрямляя локти до щелчка, медленно возвращай.',
    easier: 'Меньший вес или отжимания от скамьи.',
  ),
  Exercise(
    id: 'leg_press',
    name: 'Жим ногами',
    technique: 'Стопы на платформе на ширине плеч. Опускай платформу, пока колени не согнутся примерно до 90°, таз не отрывается от сиденья. Выжимай, не выпрямляя колени до щелчка.',
    easier: 'Меньший вес и неполная амплитуда.',
  ),
  Exercise(
    id: 'db_floor_press',
    name: 'Жим гантелей лёжа на полу',
    technique: 'Лёжа на полу, колени согнуты. Опускай гантели, пока плечи не коснутся пола, локти под ~45° к корпусу, выжимай вверх.',
    easier: 'Отжимания с колен.',
  ),
  Exercise(
    id: 'db_ohp',
    name: 'Жим гантелей стоя',
    technique: 'Стоя, пресс и ягодицы напряжены. Гантели от уровня плеч выжимай вверх над головой, не прогибая поясницу.',
    easier: 'Сидя с опорой на спину.',
  ),
  Exercise(
    id: 'db_rdl',
    name: 'Румынская тяга с гантелями',
    technique: 'Колени слегка согнуты, гантели перед бёдрами. Наклоняйся, отводя таз назад, гантели скользят вдоль ног. Спина прямая, почувствуй растяжение задней поверхности бедра.',
    easier: 'Меньший вес и амплитуда, до середины голени.',
  ),
  Exercise(
    id: 'bulgarian_split',
    name: 'Болгарские выпады',
    technique: 'Задняя нога носком на скамье или стуле. Опускайся на передней ноге, пока бедро не станет почти параллельно полу, колено над стопой. Повторы на каждую ногу.',
    easier: 'Без гантелей или обычные выпады назад.',
  ),
  Exercise(
    id: 'db_overhead_ext',
    name: 'Разгибания гантели из-за головы',
    technique: 'Держи гантель двумя руками над головой. Опускай её за голову, сгибая только локти, локти смотрят вперёд. Разгибай руки до конца.',
    easier: 'Сидя и с лёгкой гантелью.',
  ),
  Exercise(
    id: 'burpee',
    name: 'Берпи',
    technique: 'Присядь, поставь руки на пол, прыжком перейди в упор лёжа, отожмись, прыжком верни ноги к рукам и выпрыгни вверх с хлопком над головой.',
    easier: 'Без отжимания и прыжка: шагом назад и вперёд.',
    bodyweight: true,
  ),
  Exercise(
    id: 'jumping_jacks',
    name: 'Прыжки «звёздочка»',
    technique: 'Прыжком расставь ноги шире плеч и подними руки над головой, прыжком вернись обратно. Приземляйся мягко на носки, темп ровный.',
    easier: 'Без прыжка: шаг в сторону с подъёмом рук.',
    bodyweight: true,
    timed: true,
  ),
  Exercise(
    id: 'mountain_climbers',
    name: 'Альпинист',
    technique: 'Упор лёжа на прямых руках, тело прямое. По очереди быстро подтягивай колени к груди, не поднимая таз.',
    easier: 'Медленно, шагами, или руки на скамье.',
    bodyweight: true,
    timed: true,
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
    id: 'fullbody_abc',
    title: 'Фулл бади: А / Б / В',
    desc: 'Всё тело на каждой тренировке, три разных дня по кругу. Зал, 3 раза в неделю.',
    days: [
      WorkoutDay(id: 'FA', title: 'Фулл бади А', exercises: [
        PlanExercise('squat', 3, 6, 8),
        PlanExercise('bench', 3, 6, 8),
        PlanExercise('bb_row', 3, 8, 10),
        PlanExercise('db_press_seated', 2, 10, 12),
        PlanExercise('biceps', 2, 10, 12),
        PlanExercise('plank', 3, 30, 60),
      ]),
      WorkoutDay(id: 'FB', title: 'Фулл бади Б', exercises: [
        PlanExercise('deadlift', 3, 5, 5),
        PlanExercise('incline_db', 3, 8, 12),
        PlanExercise('pullups', 3, 0, 0),
        PlanExercise('lunges_legpress', 3, 10, 12),
        PlanExercise('triceps', 2, 10, 15),
        PlanExercise('hanging_leg_raise', 3, 10, 15),
      ]),
      WorkoutDay(id: 'FC', title: 'Фулл бади В', exercises: [
        PlanExercise('goblet_squat', 3, 10, 12),
        PlanExercise('dips', 3, 8, 12),
        PlanExercise('cable_row', 3, 10, 12),
        PlanExercise('rdl', 3, 8, 10),
        PlanExercise('lateral_raise', 3, 12, 15),
        PlanExercise('calf_raise', 3, 12, 20),
      ]),
    ],
  ),
  Program(
    id: 'machines',
    title: 'Новичок: тренажёры',
    desc: 'Первые 1–2 месяца в зале: простые тренажёры, учишь технику и привыкаешь к нагрузке. Всё тело, чередуй А и Б.',
    days: [
      WorkoutDay(id: 'MA', title: 'Тренажёры А', exercises: [
        PlanExercise('leg_press', 3, 10, 12),
        PlanExercise('machine_chest_press', 3, 10, 12),
        PlanExercise('lat_pulldown', 3, 10, 12),
        PlanExercise('leg_curl', 2, 12, 15),
        PlanExercise('lateral_raise', 2, 12, 15),
        PlanExercise('plank', 3, 20, 40),
      ]),
      WorkoutDay(id: 'MB', title: 'Тренажёры Б', exercises: [
        PlanExercise('goblet_squat', 3, 10, 12),
        PlanExercise('cable_row', 3, 10, 12),
        PlanExercise('db_press_seated', 3, 10, 12),
        PlanExercise('glute_bridge', 3, 12, 15),
        PlanExercise('biceps', 2, 12, 15),
        PlanExercise('triceps', 2, 12, 15),
      ]),
    ],
  ),
  Program(
    id: 'upper_lower',
    title: 'Верх / Низ',
    desc: 'Верх и низ тела по очереди, 4 раза в неделю. Когда уже есть опыт и хочется больше объёма.',
    weekdays: [1, 2, 4, 5],
    days: [
      WorkoutDay(id: 'UP', title: 'Верх', exercises: [
        PlanExercise('bench', 4, 6, 8),
        PlanExercise('bb_row', 4, 6, 10),
        PlanExercise('db_press_seated', 3, 8, 12),
        PlanExercise('lat_pulldown', 3, 8, 12),
        PlanExercise('biceps', 2, 10, 15),
        PlanExercise('triceps', 2, 10, 15),
      ]),
      WorkoutDay(id: 'LO', title: 'Низ', exercises: [
        PlanExercise('squat', 4, 6, 8),
        PlanExercise('rdl', 3, 8, 10),
        PlanExercise('lunges_legpress', 3, 10, 12),
        PlanExercise('leg_curl', 3, 10, 15),
        PlanExercise('calf_raise', 3, 12, 20),
        PlanExercise('plank', 3, 30, 60),
      ]),
    ],
  ),
  Program(
    id: 'ppl',
    title: 'Жим / Тяга / Ноги',
    desc: 'Грудь, плечи и трицепс; спина и бицепс; ноги. 3 раза в неделю, а с опытом — 6 (два круга).',
    days: [
      WorkoutDay(id: 'PUSH', title: 'Жим', exercises: [
        PlanExercise('bench', 4, 6, 8),
        PlanExercise('incline_db', 3, 8, 12),
        PlanExercise('db_press_seated', 3, 8, 12),
        PlanExercise('lateral_raise', 3, 12, 15),
        PlanExercise('triceps', 3, 10, 15),
        PlanExercise('dips', 2, 0, 0),
      ]),
      WorkoutDay(id: 'PULL', title: 'Тяга', exercises: [
        PlanExercise('pullups', 3, 0, 0),
        PlanExercise('bb_row', 3, 6, 10),
        PlanExercise('cable_row', 3, 10, 12),
        PlanExercise('face_pull', 3, 12, 15),
        PlanExercise('biceps', 3, 10, 12),
        PlanExercise('hammer_curl', 2, 10, 12),
      ]),
      WorkoutDay(id: 'LEGS', title: 'Ноги', exercises: [
        PlanExercise('squat', 4, 6, 8),
        PlanExercise('rdl', 3, 8, 10),
        PlanExercise('leg_press', 3, 10, 12),
        PlanExercise('leg_curl', 3, 10, 15),
        PlanExercise('calf_raise', 4, 12, 20),
        PlanExercise('hanging_leg_raise', 3, 10, 15),
      ]),
    ],
  ),
  Program(
    id: 'db_home',
    title: 'Гантели дома',
    desc: 'Фулл бади дома, нужны только гантели. Чередуй А и Б, 3 раза в неделю.',
    days: [
      WorkoutDay(id: 'DA', title: 'Гантели А', exercises: [
        PlanExercise('goblet_squat', 3, 10, 15),
        PlanExercise('db_floor_press', 3, 8, 12),
        PlanExercise('db_row', 3, 8, 12),
        PlanExercise('db_ohp', 3, 8, 12),
        PlanExercise('biceps', 2, 10, 15),
        PlanExercise('plank', 3, 30, 60),
      ]),
      WorkoutDay(id: 'DB', title: 'Гантели Б', exercises: [
        PlanExercise('db_rdl', 3, 10, 12),
        PlanExercise('bulgarian_split', 3, 8, 12),
        PlanExercise('pushups', 3, 0, 0),
        PlanExercise('lateral_raise', 3, 12, 15),
        PlanExercise('db_overhead_ext', 2, 10, 15),
        PlanExercise('glute_bridge', 3, 15, 20),
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
  Program(
    id: 'hiit_home',
    title: 'Кардио дома: круговая',
    desc: 'Без инвентаря. Делай упражнения подряд по одному подходу, отдых 1–2 минуты между кругами. Хорошо сжигает калории.',
    weekdays: [2, 4, 6],
    days: [
      WorkoutDay(id: 'HIIT', title: 'Круговая', exercises: [
        PlanExercise('jumping_jacks', 4, 30, 45),
        PlanExercise('bw_squat', 4, 15, 20),
        PlanExercise('pushups', 4, 8, 15),
        PlanExercise('mountain_climbers', 4, 30, 45),
        PlanExercise('reverse_lunge', 4, 10, 12),
        PlanExercise('burpee', 4, 8, 12),
        PlanExercise('plank', 4, 30, 45),
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
  Reminder(id: 'bedtime', title: 'Пора спать', body: 'Отложи телефон — через час отбой', hour: 22, minute: 30),
  Reminder(id: 'weigh', title: 'Взвешивание', body: 'Взвесься утром натощак и запиши вес', hour: 8, minute: 0, weekdays: [1]),
];
