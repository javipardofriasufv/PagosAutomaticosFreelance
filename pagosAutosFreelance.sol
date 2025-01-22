// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FreelanceContract {
    // Estructura para representar un hito del proyecto
    struct Hito {
        string descripcion; // Descripción del hito
        uint256 monto;      // Monto asociado al hito
        bool completado;    // Estado de finalización del hito
    }

    // Direcciones involucradas en el contrato
    address public cliente;    // Dirección del cliente (creador del contrato)
    address public freelancer; // Dirección del freelancer
    address public arbitro;    // Dirección del árbitro designado

    // Lista de hitos definidos en el contrato
    Hito[] public hitos;

    // Variables adicionales
    uint256 public saldo;          // Saldo total requerido para el contrato (suma de todos los hitos)
    bool public contratoActivo;    // Indica si el contrato sigue activo

    // Eventos para registrar acciones relevantes
    event ContratoCreado(address cliente, address freelancer, address arbitro); // Cuando se crea el contrato
    event HitoAgregado(uint256 indice, string descripcion, uint256 monto);      // Al agregar un hito
    event DepositoRealizado(address cliente, uint256 monto);                    // Cuando el cliente realiza un depósito
    event HitoCompletado(uint256 indice, uint256 monto);                        // Cuando se completa un hito
    event PagoLiberado(address freelancer, uint256 monto);                      // Cuando se libera un pago al freelancer
    event ContratoCancelado(address cliente, uint256 reembolso);                // Cuando se cancela el contrato
    event ArbitrajeSolicitado(uint256 indice, address solicitadoPor);           // Cuando se solicita arbitraje
    event ArbitrajeResuelto(uint256 indice, address favorecido, uint256 monto); // Cuando se resuelve un arbitraje
    event DireccionActualizada(string tipoDireccion, address direccion);        // Cuando se actualiza una dirección

    // Modificadores para restringir funciones a roles específicos
    modifier soloCliente() {
        require(msg.sender == cliente, "Solo el cliente puede ejecutar esto.");
        _; // Continúa con el resto de la función
    }

    modifier soloFreelancer() {
        require(msg.sender == freelancer, "Solo el freelancer puede ejecutar esto.");
        _;
    }

    modifier soloArbitro() {
        require(msg.sender == arbitro, "Solo el arbitro puede ejecutar esto.");
        _;
    }

    // Constructor: inicializa el contrato con las direcciones del freelancer y árbitro
    constructor(address _freelancer, address _arbitro) {
        cliente = msg.sender; // El remitente de la transacción es el cliente
        freelancer = _freelancer;
        arbitro = _arbitro;
        contratoActivo = true; // El contrato comienza activo

        emit ContratoCreado(cliente, freelancer, arbitro); // Emite el evento de creación
    }

    // Permite al cliente actualizar su dirección
    function actualizarCliente(address _nuevoCliente) public soloCliente {
        require(_nuevoCliente != address(0), "La direccion no puede ser cero.");
        cliente = _nuevoCliente;
        emit DireccionActualizada("Cliente", _nuevoCliente);
    }

    // Permite al cliente actualizar la dirección del freelancer
    function actualizarFreelancer(address _nuevoFreelancer) public soloCliente {
        require(_nuevoFreelancer != address(0), "La direccion no puede ser cero.");
        freelancer = _nuevoFreelancer;
        emit DireccionActualizada("Freelancer", _nuevoFreelancer);
    }

    // Permite al cliente actualizar la dirección del árbitro
    function actualizarArbitro(address _nuevoArbitro) public soloCliente {
        require(_nuevoArbitro != address(0), "La direccion no puede ser cero.");
        arbitro = _nuevoArbitro;
        emit DireccionActualizada("Arbitro", _nuevoArbitro);
    }

    // El cliente agrega un nuevo hito al contrato
    function agregarHito(string memory _descripcion, uint256 _monto) public soloCliente {
        require(contratoActivo, "El contrato ya no esta activo."); // Verifica que el contrato esté activo
        hitos.push(Hito(_descripcion, _monto, false)); // Crea un nuevo hito
        saldo += _monto; // Suma el monto del hito al saldo total

        emit HitoAgregado(hitos.length - 1, _descripcion, _monto); // Emite el evento de nuevo hito
    }

    // El cliente deposita fondos en el contrato
    function depositar() public payable soloCliente {
        require(msg.value == saldo, "Debe depositar exactamente el saldo total."); // Verifica que el monto depositado sea igual al saldo total
        emit DepositoRealizado(msg.sender, msg.value); // Emite el evento de depósito
    }

    // Completa un hito y libera el pago al freelancer
    function completarHito(uint256 _indice) public soloCliente {
        require(!hitos[_indice].completado, "El hito ya esta completado."); // Verifica que el hito no esté completado
        hitos[_indice].completado = true; // Marca el hito como completado
        pagarFreelancer(hitos[_indice].monto); // Libera el pago al freelancer

        emit HitoCompletado(_indice, hitos[_indice].monto); // Emite el evento de hito completado
    }

    // Similar a completarHito, pero permite liberar un monto parcial
    function completarHitoConMonto(uint256 _indice, uint256 _monto) public soloCliente {
        require(!hitos[_indice].completado, "El hito ya esta completado.");
        require(_monto > 0 && _monto <= hitos[_indice].monto, "El monto debe ser valido y menor o igual al monto del hito.");
        require(address(this).balance >= _monto, "Saldo insuficiente en el contrato.");

        pagarFreelancer(_monto); // Libera el pago parcial
        hitos[_indice].completado = true;

        emit HitoCompletado(_indice, _monto); // Emite el evento de hito completado
    }

    // Transfiere un pago directo al freelancer
    function transferirPago(uint256 _monto) public soloCliente {
        require(_monto > 0, "El monto debe ser mayor a 0.");
        require(address(this).balance >= _monto, "Saldo insuficiente en el contrato.");

        payable(freelancer).transfer(_monto); // Transfiere el monto al freelancer

        emit PagoLiberado(freelancer, _monto); // Emite el evento de pago liberado
    }

    // Cliente o freelancer pueden solicitar arbitraje para un hito específico
    function solicitarArbitraje(uint256 _indice) public {
        require(msg.sender == cliente || msg.sender == freelancer, "Solo cliente o freelancer pueden solicitar arbitraje.");
        require(!hitos[_indice].completado, "El hito ya esta completado.");

        emit ArbitrajeSolicitado(_indice, msg.sender); // Emite el evento de solicitud de arbitraje
    }

    // El árbitro resuelve el arbitraje y distribuye los fondos
    function resolverArbitraje(uint256 _indice, address _favorecido) public soloArbitro {
        require(!hitos[_indice].completado, "El hito ya esta completado.");
        require(_favorecido == cliente || _favorecido == freelancer, "El favorecido debe ser cliente o freelancer.");

        uint256 monto = hitos[_indice].monto; // Obtiene el monto del hito
        hitos[_indice].completado = true;

        if (_favorecido == freelancer) {
            pagarFreelancer(monto); // Paga al freelancer
        } else {
            payable(cliente).transfer(monto); // Reembolsa al cliente
        }

        emit ArbitrajeResuelto(_indice, _favorecido, monto); // Emite el evento de arbitraje resuelto
    }

    // Función interna para liberar un pago al freelancer
    function pagarFreelancer(uint256 _monto) internal {
        require(address(this).balance >= _monto, "Saldo insuficiente.");
        payable(freelancer).transfer(_monto);

        emit PagoLiberado(freelancer, _monto); // Emite el evento de pago liberado
    }

    // Cancela el contrato y devuelve los fondos al cliente
    function cancelarContrato() public soloCliente {
        require(address(this).balance > 0, "No hay fondos para devolver.");
        contratoActivo = false; // Marca el contrato como inactivo
        uint256 reembolso = address(this).balance;
        payable(cliente).transfer(reembolso); // Reembolsa el saldo al cliente

        emit ContratoCancelado(cliente, reembolso); // Emite el evento de contrato cancelado
    }

    // Devuelve el saldo actual del contrato
    function obtenerSaldo() public view returns (uint256) {
        return address(this).balance;
    }
}
