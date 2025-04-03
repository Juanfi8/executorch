#include "main.h"
#include <stdio.h>
#include <time.h> //TODO

UART_HandleTypeDef huart3;

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART3_UART_Init(void);
static void MX_ICACHE_Init(void);
#define PUTCHAR_PROTOTYPE int __io_putchar(int ch)

/* Extern Cpp function */
extern int executor_main(int argc, const char* argv[]);

int main(void)
{
  /* MCU Configuration--------------------------------------------------------*/
  
  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();
  
  /* Configure the system clock */
  SystemClock_Config();
  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_USART3_UART_Init();
  MX_ICACHE_Init();
  BSP_LED_Init(LED3);
  BSP_LED_Off(LED3);    
  
  /* End MCU Configuration--------------------------------------------------------*/
  //Printf
  setvbuf(stdout, NULL, _IONBF, 0); // Disable line buffering \n is required to send data

  executor_main(0,NULL); // Call the C-compatible function

  BSP_LED_On(LED3);
  
  return 0;
}
//TODO check thi stime implementation
int __attribute__((weak)) _gettimeofday(struct timeval *tv, void *tz)
{
	(void)tv;
	(void)tz;
	return 0;
}

// * @brief System Clock Configuration
// * @retval None
// */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};
  
  /** Configure the main internal regulator output voltage
  */
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE0);
  
  while(!__HAL_PWR_GET_FLAG(PWR_FLAG_VOSRDY)) {}
  
  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_BYPASS_DIGITAL;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLL1_SOURCE_HSE;
  RCC_OscInitStruct.PLL.PLLM = 4;
  RCC_OscInitStruct.PLL.PLLN = 250;
  RCC_OscInitStruct.PLL.PLLP = 2;
  RCC_OscInitStruct.PLL.PLLQ = 2;
  RCC_OscInitStruct.PLL.PLLR = 2;
  RCC_OscInitStruct.PLL.PLLRGE = RCC_PLL1_VCIRANGE_1;
  RCC_OscInitStruct.PLL.PLLVCOSEL = RCC_PLL1_VCORANGE_WIDE;
  RCC_OscInitStruct.PLL.PLLFRACN = 0;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }
  
  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
  |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2
  |RCC_CLOCKTYPE_PCLK3;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB3CLKDivider = RCC_HCLK_DIV1;
  
  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_5) != HAL_OK)
  {
    Error_Handler();
  }
  
  /** Configure the programming delay
  */
  __HAL_FLASH_SET_PROGRAM_DELAY(FLASH_PROGRAMMING_DELAY_2);
}

/**
* @brief ICACHE Initialization Function
* @param None
* @retval None
*/
static void MX_ICACHE_Init(void)
{
  
  if (HAL_ICACHE_Enable() != HAL_OK)
  {
    Error_Handler();
  }
}

/**
* @brief  Retargets the C library printf function to the USART.
*   None
* @retval None
*/
PUTCHAR_PROTOTYPE
{
  /* e.g. write a character to the USART3 and Loop until the end of transmission */
  HAL_UART_Transmit(&huart3, (uint8_t *)&ch, 1, 0xFFFF);
  return ch;
}

/**
* @brief USART3 Initialization Function
* @param None
* @retval None
*/
static void MX_USART3_UART_Init(void)
{
  huart3.Instance = USART3;
  huart3.Init.BaudRate = 9600;
  huart3.Init.WordLength = UART_WORDLENGTH_8B;
  huart3.Init.StopBits = UART_STOPBITS_1;
  huart3.Init.Parity = UART_PARITY_ODD;
  huart3.Init.Mode = UART_MODE_TX_RX;
  huart3.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart3.Init.OverSampling = UART_OVERSAMPLING_16;
  huart3.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  huart3.Init.ClockPrescaler = UART_PRESCALER_DIV1;
  huart3.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&huart3) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetTxFifoThreshold(&huart3, UART_TXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetRxFifoThreshold(&huart3, UART_RXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_DisableFifoMode(&huart3) != HAL_OK)
  {
    Error_Handler();
  }
  
}

/**
* @brief GPIO Initialization Function
* @param None
* @retval None
*/
static void MX_GPIO_Init(void)
{
  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOD_CLK_ENABLE();
}

/**
* @brief  Rx Transfer completed callback
* @note   This example shows a simple way to report end of IT Rx transfer, and 
*         you can add your own implementation.
* @retval None
*/
void UART_CharReception_Callback(void)
{
  
}
// /**
// * @brief  Function called for achieving next TX Byte sending
// * @retval None
// */
void UART_TXEmpty_Callback(void)
{
  
}

// /**
// * @brief  Function called at completion of last byte transmission
// * @retval None
// */
void UART_CharTransmitComplete_Callback(void)
{
  
}

// /**
// * @brief  UART error callbacks
// * @note   This example shows a simple way to report transfer error, and you can
// *         add your own implementation.
// * @retval None
// */
void UART_Error_Callback(void)
{
  __IO uint32_t isr_reg;
  
  /* Disable USARTx_IRQn */
  NVIC_DisableIRQ(USART3_IRQn);
  
  /* Error handling example :
  - Read USART ISR register to identify flag that leads to IT raising
  - Perform corresponding error handling treatment according to flag
  */
  isr_reg = LL_USART_ReadReg(USART3, ISR);
  if (isr_reg & LL_USART_ISR_NE)
  {
    /* Turn LED3 on: Transfer error in reception/transmission process */
    BSP_LED_On(LED3);
  }
  else
  {
    /* Turn LED3 on: Transfer error in reception/transmission process */
    BSP_LED_On(LED3);
  }
}


/**
* @brief  This function is executed in case of error occurrence.
* @retval None
*/
void Error_Handler(void)
{
  /* Toggle LED3 for error */
  while(1)
  {
    BSP_LED_Toggle(LED3);
    HAL_Delay(1000);
  }
}

