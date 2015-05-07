# Low-cost modular acquisition and stimulation system for neuroscience

This is a complete acquisition and stimulation system for timestamp-driven
neuroscience and neuroethology experiments. This system captures the instant
of occurrence of spikes and sends them to a computer through a USB JTAG-UART
interface. The computer also enqueues stimuli samples to be converted
by an DAC synchronously to the first acquisition channel.

The system is physically composed by the following components:

 * Altera MAX II CPLD (e.g. EPM2210)
 * Digital buffer for input protection (e.g. 74HC4050)
 * MAX5134 DAC
 * 32K x 8-bit SRAM (e.g. IDT71256)

More information is available in our [paper](http://arxiv.org/abs/1504.01718).


## Compiling and synthesizing

### Preparing

Edit `config.mk` and check if the Quartus II and Bluespec compiler paths
are correct. You may also pass these paths as environment variables.

### Compiling the software

    cd software && make

### Synthesizing one of the designs

    cd src/dynamic-arb && make

or

    cd src/static-arb && make


## Citing

DOI: [10.1007/978-3-319-16214-0_29](http://dx.doi.org/10.1007/978-3-319-16214-0_29)
([Preprint](http://arxiv.org/abs/1504.01718))

> Matias, Paulo, Rafael T. Guariento, Lirio OB de Almeida, and Jan FW Slaets.
> "Modular Acquisition and Stimulation System for Timestamp-Driven Neuroscience Experiments."
> In *Applied Reconfigurable Computing*, pp. 339-348. Springer International Publishing, 2015.
