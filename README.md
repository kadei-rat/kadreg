# kadreg

### Why another convention registration system?

There are a great many convention registration system codebases around. Most are the intellectual property of the convention that made them, maintained by its tech team. They often have few (if any) tests, and are rarely in statically typed languages. Almost none are open source.

Kadreg is a convention registration system intended to be different. Open-source from the beginning. Well-tested from the beginning. Statically typed, in a modern functional language (Gleam) with a strong, expressive, beautiful type system, that runs on a VM (the Erlang VM) that is unparalleled for building reliable distributed systems on. Performant and reliable.

Kadreg is initially being developed for use by a specific con, and its initial feature set will have that con's requirements in mind. But my hope is that it will eventually be picked up by other conventions that want to use it, and who then contribute back and improve it for everyone.

### License

This project is licensed under the GNU Affero General Public License v3.0. See the [LICENSE](LICENSE.md) file for details.

That means you are free to use this as a reg system for your own convention, and modify it as you like... but if you do, **you must open source any changes you make, under the same license**.

So if you improve it, you must share your improvements, so other kadreg users can benefit from them.

I would further request that you make any improvements you make as pull requests to this repository, https://github.com/kadei-rat/kadreg , following the contribution guidelines in CONTRIBUTING.md. That isn't a license requirement, but it will be easier for you than maintaining your own fork.

I think this is a very reasonable thing to ask in return for providing a high quality registration system to you for free, and I hope you agree.

### Support & questions

If you are an attendee of a con using kadreg and have a problem with your registration, please contact that con's own support channels / registration team. I will not be able to help you.

If you are a convention organiser or tech team who wants to use kadreg and has questions, feel free to email `kadei-nospam@kadreg.org.uk` (remove the `-nospam` part).

### Bug reports

If you have found a bug in Kadreg please check to see if there is an open ticket on [the GitHub issue tracker][https://github.com/kadei-rat/kadreg/issues]. If you can't find an existing ticket for the bug, open one.

Please do not file LLM-generated bug reports unless you have enough understanding of the claimed bug to verify it yourself. Bug reports which have clearly been copy-pasted from LLM output without any human having reviewed and verified it will be closed and the author banned.

We have a disclosure email, `security-nospam@kadreg.org.uk` (remove the `-nospam` part). If you want to disclose a security issue affecting a live convention that uses this reg system, please also email the tech team for that convention.

### Contributing

Prerequisites, setup, running and testing instructions, and contribution guidelines at [CONTRIBUTING.md](CONTRIBUTING.md).
