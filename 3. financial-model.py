"""
Módulo principal del modelo financiero para el simulador de impacto financiero.

Este módulo contiene la clase FinancialModel que implementa la lógica central
para evaluar el impacto financiero de decisiones estratégicas mediante
análisis de flujo de caja descontado y métricas financieras estándar.

Autor: [Tu Nombre]
Fecha: Mayo 2025
Versión: 1.0.0
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Tuple, Union
from dataclasses import dataclass
import json
import logging
from datetime import datetime, timedelta

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class FinancialResults:
    """
    Clase para almacenar los resultados de la simulación financiera.
    
    Attributes:
        npv (float): Valor Presente Neto
        irr (float): Tasa Interna de Retorno
        payback_period (float): Período de recuperación en años
        profitability_index (float): Índice de rentabilidad
        cash_flows (List[float]): Flujos de caja proyectados
        cumulative_cash_flows (List[float]): Flujos de caja acumulados
        sensitivity_analysis (Dict): Resultados del análisis de sensibilidad
        risk_metrics (Dict): Métricas de riesgo calculadas
    """
    npv: float
    irr: float
    payback_period: float
    profitability_index: float
    cash_flows: List[float]
    cumulative_cash_flows: List[float]
    sensitivity_analysis: Dict
    risk_metrics: Dict


class FinancialModel:
    """
    Clase principal para el modelado financiero y simulación de impacto.
    
    Esta clase implementa métodos para calcular métricas financieras,
    realizar análisis de sensibilidad y generar proyecciones de flujo de caja
    basadas en diferentes escenarios de decisiones estratégicas.
    """
    
    def __init__(self, config_path: str = "config/financial_parameters.json"):
        """
        Inicializa el modelo financiero con los parámetros de configuración.
        
        Args:
            config_path (str): Ruta al archivo de configuración JSON
        """
        self.config_path = config_path
        self.parameters = self._load_configuration()
        self.base_scenario = None
        self.results_cache = {}
        
        logger.info("Modelo financiero inicializado correctamente")
    
    def _load_configuration(self) -> Dict:
        """
        Carga los parámetros de configuración desde el archivo JSON.
        
        Returns:
            Dict: Diccionario con parámetros de configuración
            
        Raises:
            FileNotFoundError: Si el archivo de configuración no existe
            ValueError: Si el archivo JSON está mal formateado
        """
        try:
            with open(self.config_path, 'r', encoding='utf-8') as file:
                config = json.load(file)
            
            # Validar parámetros requeridos
            required_sections = ['simulation_parameters', 'risk_parameters']
            for section in required_sections:
                if section not in config:
                    raise ValueError(f"Sección requerida '{section}' no encontrada en configuración")
            
            return config
            
        except FileNotFoundError:
            logger.error(f"Archivo de configuración no encontrado: {self.config_path}")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"Error al parsear archivo JSON: {e}")
            raise ValueError("Archivo de configuración con formato JSON inválido")
    
    def load_base_scenario(self, scenario_path: str) -> None:
        """
        Carga el escenario base para la simulación.
        
        Args:
            scenario_path (str): Ruta al archivo JSON con datos del escenario
        """
        try:
            with open(scenario_path, 'r', encoding='utf-8') as file:
                self.base_scenario = json.load(file)
            
            # Validar estructura del escenario
            self._validate_scenario_structure(self.base_scenario)
            logger.info(f"Escenario base cargado desde: {scenario_path}")
            
        except Exception as e:
            logger.error(f"Error cargando escenario: {e}")
            raise
    
    def _validate_scenario_structure(self, scenario: Dict) -> None:
        """
        Valida que el escenario tenga la estructura requerida.
        
        Args:
            scenario (Dict): Diccionario con datos del escenario
            
        Raises:
            ValueError: Si faltan campos requeridos en el escenario
        """
        required_fields = ['initial_investment', 'revenue_projections', 
                          'cost_projections', 'time_horizon']
        
        for field in required_fields:
            if field not in scenario:
                raise ValueError(f"Campo requerido '{field}' no encontrado en escenario")
    
    def calculate_cash_flows(self, scenario: Optional[Dict] = None) -> List[float]:
        """
        Calcula los flujos de caja proyectados basados en el escenario.
        
        Args:
            scenario (Optional[Dict]): Escenario personalizado, usa base_scenario si es None
            
        Returns:
            List[float]: Lista de flujos de caja proyectados por período
        """
        if scenario is None:
            scenario = self.base_scenario
        
        if scenario is None:
            raise ValueError("No hay escenario cargado para calcular flujos de caja")
        
        time_horizon = scenario['time_horizon']
        initial_investment = scenario['initial_investment']
        revenues = scenario['revenue_projections']
        costs = scenario['cost_projections']
        
        # Asegurar que revenues y costs tengan la longitud correcta
        if len(revenues) != time_horizon:
            revenues = self._extrapolate_projections(revenues, time_horizon)
        if len(costs) != time_horizon:
            costs = self._extrapolate_projections(costs, time_horizon)
        
        # Calcular flujos de caja netos
        cash_flows = [-initial_investment]  # Inversión inicial negativa en t=0
        
        for year in range(time_horizon):
            # Aplicar inflación si está configurada
            inflation_rate = self.parameters['simulation_parameters'].get('inflation_rate', 0.03)
            inflation_factor = (1 + inflation_rate) ** year
            
            # Calcular flujo de caja del año
            revenue = revenues[year] * inflation_factor
            cost = costs[year] * inflation_factor
            
            # Aplicar impuestos
            tax_rate = self.parameters['simulation_parameters'].get('tax_rate', 0.25)
            ebit = revenue - cost
            tax = max(0, ebit * tax_rate)
            net_cash_flow = ebit - tax
            
            cash_flows.append(net_cash_flow)
        
        return cash_flows
    
    def _extrapolate_projections(self, projections: List[float], target_length: int) -> List[float]:
        """
        Extrapola proyecciones para alcanzar la longitud objetivo.
        
        Args:
            projections (List[float]): Proyecciones originales
            target_length (int): Longitud objetivo
            
        Returns:
            List[float]: Proyecciones extrapoladas
        """
        if len(projections) >= target_length:
            return projections[:target_length]
        
        # Calcular tasa de crecimiento promedio
        if len(projections) > 1:
            growth_rates = []
            for i in range(1, len(projections)):
                if projections[i-1] != 0:
                    growth_rate = (projections[i] / projections[i-1]) - 1
                    growth_rates.append(growth_rate)
            
            avg_growth = np.mean(growth_rates) if growth_rates else 0.03
        else:
            avg_growth = 0.03  # Crecimiento por defecto del 3%
        
        # Extrapolar valores faltantes
        extended_projections = projections.copy()
        last_value = projections[-1]
        
        for i in range(len(projections), target_length):
            next_value = last_value * (1 + avg_growth)
            extended_projections.append(next_value)
            last_value = next_value
        
        return extended_projections
    
    def calculate_npv(self, cash_flows: List[float], discount_rate: Optional[float] = None) -> float:
        """
        Calcula el Valor Presente Neto (VPN) de los flujos de caja.
        
        Args:
            cash_flows (List[float]): Flujos de caja proyectados
            discount_rate (Optional[float]): Tasa de descuento, usa configuración si es None
            
        Returns:
            float: Valor Presente Neto
        """
        if discount_rate is None:
            discount_rate = self.parameters['simulation_parameters']['discount_rate']
        
        npv = 0
        for year, cash_flow in enumerate(cash_flows):
            discounted_cf = cash_flow / ((1 + discount_rate) ** year)
            npv += discounted_cf
        
        return npv
    
    def calculate_irr(self, cash_flows: List[float], max_iterations: int = 1000) -> float:
        """
        Calcula la Tasa Interna de Retorno (TIR) usando el método de Newton-Raphson.
        
        Args:
            cash_flows (List[float]): Flujos de caja proyectados
            max_iterations (int): Número máximo de iteraciones
            
        Returns:
            float: Tasa Interna de Retorno
        """
        # Verificar que hay al menos un flujo negativo y uno positivo
        if not any(cf < 0 for cf in cash_flows) or not any(cf > 0 for cf in cash_flows):
            return float('nan')
        
        # Estimación inicial basada en payback simple
        initial_guess = 0.1
        
        for iteration in range(max_iterations):
            # Calcular VPN y su derivada
            npv = sum(cf / ((1 + initial_guess) ** t) for t, cf in enumerate(cash_flows))
            npv_derivative = sum(-t * cf / ((1 + initial_guess) ** (t + 1)) for t, cf in enumerate(cash_flows))
            
            if abs(npv) < 1e-10:  # Convergencia alcanzada
                return initial_guess
            
            if abs(npv_derivative) < 1e-10:  # Evitar división por cero
                break
            
            # Actualización Newton-Raphson
            new_guess = initial_guess - npv / npv_derivative
            
            if abs(new_guess - initial_guess) < 1e-10:  # Convergencia alcanzada
                return new_guess
            
            initial_guess = new_guess
        
        return float('nan')  # No convergió
    
    def calculate_payback_period(self, cash_flows: List[float]) -> float:
        """
        Calcula el período de recuperación de la inversión.
        
        Args:
            cash_flows (List[float]): Flujos de caja proyectados
            
        Returns:
            float: Período de recuperación en años
        """
        cumulative_cf = 0
        
        for year, cash_flow in enumerate(cash_flows):
            cumulative_cf += cash_flow
            
            if cumulative_cf >= 0:
                if year == 0:
                    return 0
                
                # Interpolación para obtener el período exacto
                previous_cumulative = cumulative_cf - cash_flow
                fraction = abs(previous_cumulative) / cash_flow
                return year - 1 + fraction
        
        return float('inf')  # No se recupera la inversión
    
    def calculate_profitability_index(self, cash_flows: List[float], 
                                    discount_rate: Optional[float] = None) -> float:
        """
        Calcula el índice de rentabilidad del proyecto.
        
        Args:
            cash_flows (List[float]): Flujos de caja proyectados
            discount_rate (Optional[float]): Tasa de descuento
            
        Returns:
            float: Índice de rentabilidad
        """
        if discount_rate is None:
            discount_rate = self.parameters['simulation_parameters']['discount_rate']
        
        # Valor presente de flujos positivos
        pv_positive = 0
        for year in range(1, len(cash_flows)):
            if cash_flows[year] > 0:
                pv_positive += cash_flows[year] / ((1 + discount_rate) ** year)
        
        # Inversión inicial (valores negativos)
        initial_investment = abs(cash_flows[0])
        
        if initial_investment == 0:
            return float('inf')
        
        return pv_positive / initial_investment
    
    def run_simulation(self, scenario: Optional[Dict] = None) -> FinancialResults:
        """
        Ejecuta la simulación completa y calcula todas las métricas financieras.
        
        Args:
            scenario (Optional[Dict]): Escenario personalizado
            
        Returns:
            FinancialResults: Objeto con todos los resultados de la simulación
        """
        logger.info("Iniciando simulación financiera")
        
        # Calcular flujos de caja
        cash_flows = self.calculate_cash_flows(scenario)
        cumulative_cash_flows = np.cumsum(cash_flows).tolist()
        
        # Calcular métricas principales
        npv = self.calculate_npv(cash_flows)
        irr = self.calculate_irr(cash_flows)
        payback = self.calculate_payback_period(cash_flows)
        profitability_index = self.calculate_profitability_index(cash_flows)
        
        # Realizar análisis de sensibilidad
        sensitivity_analysis = self._perform_sensitivity_analysis(scenario)
        
        # Calcular métricas de riesgo
        risk_metrics = self._calculate_risk_metrics(cash_flows, scenario)
        
        results = FinancialResults(
            npv=npv,
            irr=irr,
            payback_period=payback,
            profitability_index=profitability_index,
            cash_flows=cash_flows,
            cumulative_cash_flows=cumulative_cash_flows,
            sensitivity_analysis=sensitivity_analysis,
            risk_metrics=risk_metrics
        )
        
        logger.info("Simulación completada exitosamente")
        return results
    
    def _perform_sensitivity_analysis(self, scenario: Optional[Dict] = None) -> Dict:
        """
        Realiza análisis de sensibilidad sobre variables clave.
        
        Args:
            scenario (Optional[Dict]): Escenario para análisis
            
        Returns:
            Dict: Resultados del análisis de sensibilidad
        """
        if scenario is None:
            scenario = self.base_scenario
        
        sensitivity_vars = ['discount_rate', 'revenue_growth', 'cost_inflation']
        variations = [-0.2, -0.1, 0, 0.1, 0.2]  # Variaciones del -20% al +20%
        
        sensitivity_results = {}
        
        for var in sensitivity_vars:
            var_results = {}
            
            for variation in variations:
                modified_scenario = self._modify_scenario_for_sensitivity(
                    scenario.copy(), var, variation
                )
                
                cash_flows = self.calculate_cash_flows(modified_scenario)
                npv = self.calculate_npv(cash_flows)
                
                var_results[f"{variation:.1%}"] = npv
            
            sensitivity_results[var] = var_results
        
        return sensitivity_results
    
    def _modify_scenario_for_sensitivity(self, scenario: Dict, variable: str, 
                                       variation: float) -> Dict:
        """
        Modifica un escenario para el análisis de sensibilidad.
        
        Args:
            scenario (Dict): Escenario base
            variable (str): Variable a modificar
            variation (float): Porcentaje de variación
            
        Returns:
            Dict: Escenario modificado
        """
        if variable == 'discount_rate':
            base_rate = self.parameters['simulation_parameters']['discount_rate']
            self.parameters['simulation_parameters']['discount_rate'] = base_rate * (1 + variation)
        
        elif variable == 'revenue_growth':
            revenues = scenario['revenue_projections']
            growth_factor = 1 + variation
            scenario['revenue_projections'] = [r * growth_factor for r in revenues]
        
        elif variable == 'cost_inflation':
            costs = scenario['cost_projections']
            inflation_factor = 1 + variation
            scenario['cost_projections'] = [c * inflation_factor for c in costs]
        
        return scenario
    
    def _calculate_risk_metrics(self, cash_flows: List[float], 
                              scenario: Optional[Dict] = None) -> Dict:
        """
        Calcula métricas de riesgo para el proyecto.
        
        Args:
            cash_flows (List[float]): Flujos de caja proyectados
            scenario (Optional[Dict]): Escenario actual
            
        Returns:
            Dict: Métricas de riesgo calculadas
        """
        risk_params = self.parameters['risk_parameters']
        
        # Calcular volatilidad de flujos de caja
        if len(cash_flows) > 1:
            cf_returns = []
            for i in range(1, len(cash_flows)):
                if cash_flows[i-1] != 0:
                    cf_return = (cash_flows[i] / abs(cash_flows[i-1])) - 1
                    cf_returns.append(cf_return)
            
            volatility = np.std(cf_returns) if cf_returns else 0
        else:
            volatility = 0
        
        # Métricas de riesgo
        risk_metrics = {
            'cash_flow_volatility': volatility,
            'market_risk_factor': risk_params.get('market_volatility', 0.15),
            'operational_risk_factor': risk_params.get('operational_risk', 0.10),
            'financial_risk_factor': risk_params.get('financial_risk', 0.08),
            'overall_risk_score': self._calculate_overall_risk_score(volatility, risk_params)
        }
        
        return risk_metrics
    
    def _calculate_overall_risk_score(self, volatility: float, risk_params: Dict) -> float:
        """
        Calcula un score de riesgo general del proyecto.
        
        Args:
            volatility (float): Volatilidad de flujos de caja
            risk_params (Dict): Parámetros de riesgo
            
        Returns:
            float: Score de riesgo (0-1, donde 1 es más riesgo)
        """
        market_weight = 0.4
        operational_weight = 0.3
        financial_weight = 0.2
        volatility_weight = 0.1
        
        risk_score = (
            risk_params.get('market_volatility', 0.15) * market_weight +
            risk_params.get('operational_risk', 0.10) * operational_weight +
            risk_params.get('financial_risk', 0.08) * financial_weight +
            min(volatility, 1.0) * volatility_weight
        )
        
        return min(risk_score, 1.0)  # Limitar a máximo 1.0
    
    def generate_report(self, results: FinancialResults, 
                       output_format: str = "dict") -> Union[Dict, str]:
        """
        Genera un reporte detallado de los resultados de la simulación.
        
        Args:
            results (FinancialResults): Resultados de la simulación
            output_format (str): Formato del reporte ("dict", "json", "summary")
            
        Returns:
            Union[Dict, str]: Reporte en el formato especificado
        """
        report_data = {
            "simulation_summary": {
                "date": datetime.now().isoformat(),
                "npv": round(results.npv, 2),
                "irr": round(results.irr, 4) if not np.isnan(results.irr) else None,
                "payback_period": round(results.payback_period, 2) if results.payback_period != float('inf') else None,
                "profitability_index": round(results.profitability_index, 3)
            },
            "cash_flow_analysis": {
                "projected_cash_flows": [round(cf, 2) for cf in results.cash_flows],
                "cumulative_cash_flows": [round(cf, 2) for cf in results.cumulative_cash_flows]
            },
            "sensitivity_analysis": results.sensitivity_analysis,
            "risk_assessment": results.risk_metrics
        }
        
        if output_format == "json":
            return json.dumps(report_data, indent=2, ensure_ascii=False)
        elif output_format == "summary":
            return self._generate_summary_report(results)
        else:
            return report_data
    
    def _generate_summary_report(self, results: FinancialResults) -> str:
        """
        Genera un reporte resumen en formato texto.
        
        Args:
            results (FinancialResults): Resultados de la simulación
            
        Returns:
            str: Reporte resumen en texto
        """
        irr_str = f"{results.irr:.2%}" if not np.isnan(results.irr) else "No calculable"
        payback_str = f"{results.payback_period:.1f} años" if results.payback_period != float('inf') else "No se recupera"
        
        summary = f"""
REPORTE EJECUTIVO - SIMULACIÓN FINANCIERA
=========================================

MÉTRICAS PRINCIPALES:
• Valor Presente Neto (VPN): ${results.npv:,.2f}
• Tasa Interna de Retorno (TIR): {irr_str}
• Período de Recuperación: {payback_str}
• Índice de Rentabilidad: {results.profitability_index:.2f}

EVALUACIÓN DE RIESGO:
• Score de Riesgo General: {results.risk_metrics['overall_risk_score']:.2%}
• Volatilidad de Flujos: {results.risk_metrics['cash_flow_volatility']:.2%}

RECOMENDACIÓN:
"""
        
        # Agregar recomendación basada en métricas
        if results.npv > 0 and results.profitability_index > 1:
            summary += "✅ PROYECTO RECOMENDADO - Métricas financieras positivas"
        elif results.npv > 0 but results.profitability_index < 1.2:
            summary += "⚠️  PROYECTO MARGINAL - Evaluar alternativas"
        else:
            summary += "❌ PROYECTO NO RECOMENDADO - Métricas financieras negativas"
        
        return summary