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
    A["measure_weight(obj, cow_id)"] --> B["Инициализация переменных"]
    B --> C["animal_id_list.append(cow_id)"]
    C --> D["weight_arr = []"]
    D --> E["start_filter(obj)"]
    
    E --> F["next_time = time.time() + 1"]
    F --> G["drink_start_time = timeit.default_timer()"]
    G --> H["gpio_state = False"]
    H --> I["start_timedate = datetime.now()"]
    
    I --> J["Создание объекта Values"]
    J --> K{"SPRAYER включен?"}
    K -->|Да| L["sprayer = Sprayer(values)"]
    K -->|Нет| M["weight_on_moment = _take_weight(obj, 20)"]
    
    L --> M
    M --> N["logger.info(weight_on_moment)"]
    N --> O{"weight_on_moment > 20?"}
    
    O -->|Нет| P["GPIO.cleanup()"]
    O -->|Да| Q["current_animal_id = __animal_rfid()"]
    
    Q --> R["is_valid_rfid(current_animal_id)"]
    R --> S{"RFID валидный?"}
    S -->|Да| T["animal_id_list.append(current_animal_id)"]
    S -->|Нет| U["logger.warning('Ignored suspicious RFID')"]
    
    T --> V["weight_on_moment = _take_weight(obj, 20)"]
    U --> V
    V --> W["current_time = time.time()"]
    W --> X["time_to_wait = next_time - current_time"]
    
    X --> Y{"SPRAYER включен?"}
    Y -->|Да| Z["Обработка опрыскивания"]
    Y -->|Нет| AA["Проверка времени ожидания"]
    
    Z --> BB{"values.flag?"}
    BB -->|Нет| CC["gpio_state = sprayer.spray_main_function()"]
    BB -->|Да| DD["Проверка таймера"]
    
    CC --> EE["values = sprayer.new_start_timer()"]
    DD --> FF{"time_to_wait < 0 AND round(time, 0) % 5 == 0?"}
    FF -->|Да| GG["values.flag = False"]
    FF -->|Нет| AA
    
    EE --> AA
    GG --> AA
    AA --> HH{"time_to_wait < 0?"}
    HH -->|Да| II["weight_arr.append(weight_on_moment)"]
    HH -->|Нет| O
    
    II --> JJ["next_time = time.time() + 1"]
    JJ --> KK["logger.debug(weight_arr)"]
    KK --> O
    
    P --> LL{"weight_arr пустой?"}
    LL -->|Да| MM["return 0, [], '', ''"]
    LL -->|Нет| NN["most_common_animal_id = Counter().most_common(1)"]
    
    NN --> OO["weight_finall = statistics.median(weight_arr)"]
    OO --> PP{"SPRAYER включен?"}
    PP -->|Да| QQ["gpio_state = sprayer.gpio_state_check()"]
    PP -->|Нет| RR["return результаты"]
    
    QQ --> RR
    RR --> SS["return weight_finall, weight_arr, start_timedate, most_common_animal_id"]
    
    TT["Exception"] --> UU["logger.error('measure_weight Error')"]
    UU --> VV["GPIO.cleanup()"]
    VV --> WW["return 0, [], ''"]
    
    style A fill:#e1f5fe
    style O fill:#fff3e0
    style Y fill:#f3e5f5
    style LL fill:#e8f5e8
    style TT fill:#ffebee
```