# Sigil

Библиотека для парсинга аргументов командной строки (CLI parser) на языке Surge.

## Описание

Sigil — это библиотека для создания CLI-приложений с поддержкой:
- Флагов (boolean, integer, string)
- Подкоманд (subcommands)
- Позиционных аргументов
- Автоматической генерации справки (help)
- Валидации обязательных опций

Библиотека предоставляет типобезопасный API для определения спецификации команд и опций, а также парсинг аргументов командной строки с детальной диагностикой ошибок.

## Структура проекта

```
sigil/
├── spec.sg      # Спецификация типов (AppSpec, CmdSpec, OptSpec)
├── tokens.sg    # Определение токенов для лексического анализа
├── lexer.sg     # Лексический анализатор аргументов командной строки
├── parse.sg     # Парсер, преобразующий токены в структуру Parsed
├── parsed.sg    # Структура для хранения распарсенных значений
├── diag.sg      # Диагностика (ошибки и справка)
├── imports.sg   # Импорты стандартной библиотеки
└── surge.toml   # Манифест проекта Surge
```

## Основные компоненты

### AppSpec

Главная спецификация приложения. Создается через `AppSpec::new(name)` и позволяет:
- Определять глобальные опции
- Добавлять подкоманды
- Настраивать позиционные аргументы

### CmdSpec

Спецификация команды (корневой или подкоманды). Поддерживает:
- Опции команды
- Вложенные подкоманды
- Позиционные аргументы

### OptSpec

Спецификация опции с поддержкой типов:
- `Bool` — флаги (true/false)
- `Int` — целочисленные значения
- `String` — строковые значения
- `ManyString` — множественные строковые значения (для позиционных аргументов)

### Parsed

Результат парсинга, содержащий:
- Имя выбранной команды
- Map значений опций по их ID

## API

### Создание приложения

```surge
let mut app = AppSpec::new("myapp");
```

### Добавление опций

```surge
// Boolean флаг
let verbose_key = app.flag_bool("--verbose", Some("-v"));

// Integer опция с значением по умолчанию
let port_key = app.opt_int("--port", Some("-p"), 8080);

// String опция
let config_key = app.opt_string("--config", Some("-c"), nothing);
```

### Добавление подкоманд

```surge
let mut build_cmd = app.cmd("build");
build_cmd.help("Build the project");
let build_opt_key = build_cmd.flag_bool("--release", nothing);
```

### Позиционные аргументы

```surge
let files_key = app.positionals_many("files");
```

### Парсинг аргументов

```surge
let result = parse(argv, &app);
compare result {
    Success(parsed) => {
        // Использование распарсенных значений
        let verbose = parsed.get_bool(verbose_key);
        let port = parsed.get_int(port_key);
        // ...
    }
    err => compare err {
        Help(usage) => {
            // Показать справку
        }
        ErrorDiag(err) => {
            // Обработать ошибку
        }
    }
}
```

## Примеры использования

### Простое приложение с флагами

```surge
let mut app = AppSpec::new("greet");
let verbose_key = app.flag_bool("--verbose", Some("-v"));
let name_key = app.opt_string("--name", Some("-n"), Some("World"));

let result = parse(argv, &app);
compare result {
    Success(parsed) => {
        let name = parsed.get_string(name_key);
        let verbose = parsed.get_bool(verbose_key);
        // ...
    }
    finally => {}
}
```

### Приложение с подкомандами

```surge
let mut app = AppSpec::new("git");

// Глобальные опции
let verbose_key = app.flag_bool("--verbose", Some("-v"));

// Подкоманда commit
let mut commit_cmd = app.cmd("commit");
commit_cmd.help("Record changes to the repository");
let message_key = commit_cmd.opt_string("--message", Some("-m"), nothing);

// Подкоманда push
let mut push_cmd = app.cmd("push");
push_cmd.help("Update remote refs along with associated objects");

let result = parse(argv, &app);
compare result {
    Success(parsed) => {
        if parsed.is_it("commit") {
            // Обработка команды commit
        } else if parsed.is_it("push") {
            // Обработка команды push
        }
    }
    finally => {}
}
```

## Поддерживаемые форматы аргументов

### Длинные опции
- `--flag` — boolean флаг
- `--option=value` — опция со значением через `=`
- `--option value` — опция со значением через пробел

### Короткие опции
- `-f` — одиночный флаг
- `-abc` — группа флагов (эквивалентно `-a -b -c`)
- `-p8080` — флаг со значением (если значение начинается с цифры)

### Специальные токены
- `--` — останавливает парсинг опций, все последующие аргументы трактуются как позиционные

## Обработка ошибок

Библиотека возвращает `Erring<Parsed, ParseDiag>`, где `ParseDiag` может быть:
- `Help(string)` — запрос справки (автоматически генерируется при `--help` или `-h`)
- `ErrorDiag(Error)` — ошибка парсинга с описанием проблемы

Примеры ошибок:
- Неизвестный флаг
- Отсутствует значение для опции
- Некорректное значение (например, не число для `opt_int`)
- Отсутствует обязательная опция

## Требования

- Surge версии 0.1.8 или выше
