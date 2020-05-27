import logging
import os

class AlxFormatter(logging.Formatter):

	debug_fmt  = "%(asctime)s - VERBOSE: %(msg)s"
	info_fmt = "%(asctime)s - INFO: %(msg)s"
	warning_fmt = "%(asctime)s - WARNING! %(msg)s"
	error_fmt  = "%(asctime)s - %(name)s: ERROR! %(msg)s (DEV: %(module)s, line %(lineno)d)"
	critical_fmt = "%(asctime)s - %(name)s: SUCCESS! %(msg)s"

	def __init__(self, fmt="%(levelno)d: %(msg)s", datefmt="%H:%M:%S, %Y-%m-%d"):
		super().__init__(fmt=fmt, datefmt=datefmt, style='%')  

	def format(self, record):
		# Save the original format configured by the user
		# when the logger formatter was instantiated
		format_original = self._style._fmt

		# Replace the original format with one customized by logging level
		if record.levelno == logging.DEBUG:
			self._style._fmt = AlxFormatter.debug_fmt
		elif record.levelno == logging.INFO:
			self._style._fmt = AlxFormatter.info_fmt
		elif record.levelno == logging.WARNING:
			self._style._fmt = AlxFormatter.warning_fmt
		elif record.levelno == logging.ERROR:
			self._style._fmt = AlxFormatter.error_fmt
		elif record.levelno == logging.CRITICAL:
			self._style._fmt = AlxFormatter.critical_fmt

		# Call the original formatter class to do the grunt work
		result = logging.Formatter.format(self, record)

		# Restore the original format configured by the user
		self._style._fmt = format_original

		return result

class AlxLog(object):

	def __init__(self, script_name="script", name="ALEXANDRIA"):
		self.script_name = script_name
		logger = logging.getLogger(name)
		self.logger = logger
		logger.setLevel(logging.DEBUG)

		# create console handler and set level to debug
		handler = logging.StreamHandler()
		self.handler = handler
		handler.setLevel(logging.DEBUG)

		# create formatter
		formatter = AlxFormatter()
		self.formatter = formatter

		# add formatter to ch
		handler.setFormatter(formatter)
		# add ch to logger
		logger.addHandler(handler)
		
		self.initialization()

	def info(self, msg):
		self.logger.info(msg)

	def verbose(self, msg):
		self.logger.debug(msg)

	def warn(self, msg):
		self.logger.warning(msg)

	def error(self, msg):
		self.logger.error(msg)

	def success(self, msg):
		self.logger.critical(msg)

	def sep(self, character='-', width=124):
		format_original = AlxFormatter.info_fmt
		AlxFormatter.info_fmt = "%(msg)s"
		self.info(str(character*width))
		AlxFormatter.info_fmt = format_original

	def initialization(self):
		self.sep('=')
		format_original = AlxFormatter.info_fmt
		AlxFormatter.info_fmt = "%(asctime)s - ALEXANDRIA: %(msg)s"
		self.logger.info(f"Initialized logger, ready for {self.script_name}.")
		AlxFormatter.info_fmt = format_original
		self.formatter.datefmt = "%H:%M:%S"