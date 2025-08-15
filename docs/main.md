```markdown
# Flowchart: Main PCF Execution Process

This Mermaid flowchart illustrates the startup and execution flow of the main_pcf.py script, detailing the following key stages:

## Initialization
- Script starts by importing necessary headers and packages
- Defines a list of required packages (loguru, requests, pyserial, RPi.GPIO)
- Handles GPIO import with fallback to mock GPIO for non-Raspberry Pi environments

## Logging Configuration
- Sets up log directories based on environment (Raspberry Pi or development)
- Configures logging levels and log file management
  - Main log file: scales.log (daily rotation, 1-month retention)
  - Error log file: errors.log (ERROR level, daily rotation)

## Execution Flow
- Imports core modules and configuration manager
- Determines debug level based on DEBUG flag
- Defines main() function with error handling
- Calls scales_v71() as primary processing function
- Handles potential exceptions with logging

## Program Termination
- Gracefully handles successful execution or error scenarios
- Ensures proper program exit
```
```mermaid
flowchart TD
    A["Запуск main_pcf.py"] --> B["Импорт _headers и install_packages"]
    B --> C["Определение списка требуемых пакетов"]
    C --> D["requirement_list: loguru, requests, pyserial, RPi.GPIO, wabson.chafon-rfid"]
    D --> E["install_packages(requirement_list)"]
    E --> F{"Проверка RPi.GPIO"}
    
    F -->|Успешно| G["Импорт RPi.GPIO"]
    F -->|RuntimeError| H["Импорт MockGPIO из __gpio_simulator"]
    
    G --> I["Настройка путей логов для Raspberry Pi"]
    I --> J["log_dir = /home/pi/scales7.1/scales_submodule/loguru/scales_log"]
    J --> K["Создание директорий для логов"]
    K --> L["Установка прав доступа chmod -R 777"]
    
    H --> M["Настройка путей логов для разработки"]
    M --> N["log_dir = ../feeder_log"]
    
    L --> O["Импорт остальных модулей"]
    N --> O
    O --> P["Импорт: _lib_pcf.scales_v71, loguru.logger, _config_manager.ConfigManager"]
    P --> Q["Импорт _glb_val.DEBUG"]
    
    Q --> R["Создание экземпляра ConfigManager"]
    R --> S{"DEBUG == 1?"}
    S -->|Да| T["debug_level = 'DEBUG'"]
    S -->|Нет| U["debug_level = 'CRITICAL'"]
    
    T --> V["Настройка основного логгера"]
    U --> V
    V --> W["Файл: scales.log, ротация: 1 день, хранение: 1 месяц"]
    W --> X["Настройка логгера ошибок"]
    X --> Y["Файл: errors.log, уровень: ERROR, ротация: 1 день"]
    
    Y --> Z["Определение функции main()"]
    Z --> AA["Декоратор @logger.catch()"]
    AA --> BB["try-except блок"]
    BB --> CC["Вызов scales_v71()"]
    
    CC --> DD{"Исключение?"}
    DD -->|Нет| EE["Успешное выполнение"]
    DD -->|Да| FF["logger.error('Error: {e}')"]
    
    FF --> GG["Завершение программы"]
    EE --> GG
    
    GG --> HH["Вызов main()"]
    HH --> II["Конец программы"]
```